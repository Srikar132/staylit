package com.staylit.app.services.scroll

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat
import com.staylit.app.R

/**
 * The "dynamic island": a small black pill at the top of the screen, placed around the camera cutout with
 * the DisplayCutout API, showing the live session count next to a tiny Lit (or the break countdown).
 *
 * Tap it and it grows smoothly into a card (count, mood, today, time, Take a break), like a mini-player.
 * Tap outside, tap its header, wait 6 s, rotate or leave the short-form view and it shrinks back.
 *
 * It is an accessibility overlay window (no extra permission). The window is always exactly the size of
 * what is drawn (pill, or card) and is resized once per expand / collapse, while the inner view is what
 * animates, so it is smooth and can never leave a large transparent area that would block the app.
 * It shows only our own numbers, nothing from the screen. Placement maths is in the pure [IslandGeometry].
 */
class ScrollIsland(
    private val service: AccessibilityService,
    private val host: Host,
) {
    /** What the island needs from the rest of the feature. */
    interface Host {
        /** Numbers for the expanded card, read fresh each time it refreshes. */
        fun cardState(): IslandCardState

        /** Time left on a break pass for the app in front, or null. Drives the collapsed countdown. */
        fun passRemainingMs(): Long?

        fun onTakeBreak()
        fun onEndBreakEarly()
    }

    private companion object {
        const val TAG = "ScrollDamage"
        const val MORPH_MS = 280L
        const val AUTO_COLLAPSE_MS = 6_000L
        const val TICK_MS = 1_000L
        const val MAX_CARD_WIDTH_DP = 360
    }

    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density get() = service.resources.displayMetrics.density

    // ---- views (null while nothing is attached)
    private var root: FrameLayout? = null
    private var surface: FrameLayout? = null
    private var header: LinearLayout? = null
    private var body: LinearLayout? = null
    private var countView: TextView? = null
    private var dotView: View? = null
    private var litView: ImageView? = null
    private var timerView: TextView? = null
    private var bigCount: TextView? = null
    private var moodChip: TextView? = null
    private var meter: List<View> = emptyList()
    private var statToday: TextView? = null
    private var statTime: TextView? = null
    private var statPassBox: View? = null
    private var statPass: TextView? = null
    private var primaryButton: TextView? = null

    private var layout: IslandLayout? = null
    private var cardWidthPx = 0
    private var cardHeightPx = 0
    private var morph: ValueAnimator? = null

    /** The caller wants the pill visible (so it can come back after a rotation). */
    private var wanted = false
    private var count = 0
    private var level = 1

    /** A failed add (bad token, OEM restriction) turns the island off for the session, never crashes. */
    private var failed = false

    var isExpanded: Boolean = false
        private set

    private var animating = false

    /** Bumped on every morph so a late callback of an older one is ignored. */
    private var generation = 0

    val isShown: Boolean get() = root != null

    private val tick = object : Runnable {
        override fun run() {
            if (root == null) return
            render()
            if (isExpanded) fillBody()
            scheduleTickIfNeeded()
        }
    }
    private val autoCollapse = Runnable { collapse() }

    // ------------------------------------------------------------------ public

    fun show(count: Int, level: Int) {
        wanted = true
        this.count = count
        this.level = level
        if (root != null) {
            render()
            return
        }
        attach(null)
    }

    fun update(count: Int, level: Int) {
        this.count = count
        this.level = level
        if (root == null) return
        render()
        if (isExpanded) fillBody() else bump()
    }

    /** Pass started, ended or changed: redraw the countdown and the card's main button. */
    fun refresh() {
        if (root == null) return
        render()
        if (isExpanded) fillBody()
        scheduleTickIfNeeded()
    }

    fun hide() {
        wanted = false
        remove()
    }

    /** Rotation, fold/unfold, display size or font scale changed: place the pill again, collapsed. */
    fun onConfigurationChanged() {
        if (!wanted) return
        remove()
        attach(null)
    }

    /** Shrinks the card back to the pill. [instant] skips the animation (another surface is taking over). */
    fun collapse(instant: Boolean = false) {
        if (!isExpanded || root == null) return
        if (animating && !instant) return
        handler.removeCallbacks(autoCollapse)
        runMorph(expanding = false, instant = instant)
    }

    // ------------------------------------------------------------------ window

    private fun baseFlags() =
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

    private fun params(width: Int, height: Int, x: Int, y: Int) = WindowManager.LayoutParams(
        width,
        height,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        baseFlags(),
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        this.x = x
        this.y = y
        // Let the pill draw into the cutout area itself.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    private fun attach(cutoutsOverride: List<PxRect>?) {
        if (failed || root != null) return
        try {
            val (screenW, screenH) = screenSize()
            val cutouts = cutoutsOverride ?: readCutouts(null)
            val l = IslandGeometry.compute(screenW, screenH, density, cutouts, statusBarHeight()) ?: return
            val view = buildTree(l)
            windowManager.addView(view, params(l.widthPx, l.heightPx, l.xOffsetPx, l.yPx))
            root = view
            layout = l
            cardWidthPx = minOf(screenW - dp(32), dp(MAX_CARD_WIDTH_DP))
            render()
            scheduleTickIfNeeded()

            // API 28-29 only expose the cutout once a view is attached: place again if it differs.
            view.post { refine(view) }
        } catch (e: Exception) {
            failed = true
            root = null
            Log.e(TAG, "island add failed, island off for this session", e)
        }
    }

    private fun refine(view: View) {
        if (root !== view || !wanted || isExpanded) return
        val cutouts = readCutouts(view)
        val (screenW, screenH) = screenSize()
        val better = IslandGeometry.compute(screenW, screenH, density, cutouts, statusBarHeight())
        if (better != null && better != layout) {
            remove()
            attach(cutouts)
        }
    }

    private fun remove() {
        handler.removeCallbacks(tick)
        handler.removeCallbacks(autoCollapse)
        morph?.cancel()
        morph = null
        val view = root ?: return
        root = null
        surface = null
        header = null
        body = null
        countView = null
        dotView = null
        litView = null
        timerView = null
        bigCount = null
        moodChip = null
        meter = emptyList()
        statToday = null
        statTime = null
        statPassBox = null
        statPass = null
        primaryButton = null
        layout = null
        isExpanded = false
        animating = false
        try {
            windowManager.removeViewImmediate(view)
        } catch (e: Exception) {
            // Already gone (service restarted): nothing to clean up.
        }
    }

    // ------------------------------------------------------------------ views

    private fun dp(v: Int) = (v * density).toInt()

    private fun font(res: Int): Typeface = try {
        ResourcesCompat.getFont(service, res) ?: Typeface.DEFAULT
    } catch (e: Exception) {
        Typeface.DEFAULT
    }

    private fun color(res: Int) = service.getColor(res)

    private fun roundRect(fill: Int, radiusPx: Float) = GradientDrawable().apply {
        setColor(fill)
        cornerRadius = radiusPx
    }

    private fun buildTree(l: IslandLayout): FrameLayout {
        val medium = font(R.font.space_grotesk_medium)
        val bold = font(R.font.space_grotesk_bold)
        val regular = font(R.font.space_grotesk_regular)
        val white = color(R.color.scroll_island_text)
        val muted = color(R.color.scroll_card_muted)

        // ---- header: the pill itself (stays at the top when the card is open)
        val dot = View(service).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL }
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(8)).apply { marginEnd = dp(6) }
        }
        val countText = TextView(service).apply {
            setTextColor(white)
            typeface = bold
            // dp, not sp: the pill must never outgrow the cutout height when the font is scaled up.
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15f)
            includeFontPadding = false
            gravity = Gravity.CENTER_VERTICAL
        }
        val lit = ImageView(service).apply {
            setImageResource(R.drawable.lit_scroll_pill)
            scaleType = ImageView.ScaleType.FIT_CENTER
        }
        val timer = TextView(service).apply {
            setTextColor(white)
            typeface = medium
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
            includeFontPadding = false
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        val head = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            contentDescription = "Scroll damage. Double tap for details."
        }
        if (l.wrapsCutout) {
            val side = (l.widthPx - l.cutoutWidthPx) / 2
            val left = LinearLayout(service).apply {
                gravity = Gravity.CENTER
                addView(dot)
                addView(countText)
            }
            val right = FrameLayout(service).apply {
                addView(lit, FrameLayout.LayoutParams(dp(22), dp(22), Gravity.CENTER))
                addView(timer, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
            }
            head.addView(left, LinearLayout.LayoutParams(side, LinearLayout.LayoutParams.MATCH_PARENT))
            // The camera hole sits in this gap, in the pill's black middle.
            head.addView(View(service), LinearLayout.LayoutParams(l.cutoutWidthPx, 1))
            head.addView(right, LinearLayout.LayoutParams(side, LinearLayout.LayoutParams.MATCH_PARENT))
        } else {
            head.gravity = Gravity.CENTER
            head.addView(dot)
            head.addView(countText)
            val right = FrameLayout(service).apply {
                addView(lit, FrameLayout.LayoutParams(dp(22), dp(22), Gravity.CENTER))
                addView(timer, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
            }
            head.addView(right, LinearLayout.LayoutParams(dp(40), dp(28)).apply { marginStart = dp(8) })
        }

        // ---- body: the details shown when expanded
        val big = TextView(service).apply {
            setTextColor(white)
            typeface = bold
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 36f)
            includeFontPadding = false
        }
        val bigLabel = TextView(service).apply {
            text = "this session"
            setTextColor(muted)
            typeface = regular
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
        }
        val chip = TextView(service).apply {
            typeface = medium
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
            setPadding(dp(12), dp(5), dp(12), dp(5))
        }
        val topRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                LinearLayout(service).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(big)
                    addView(bigLabel)
                },
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
            )
            addView(chip)
        }
        val meterRow = LinearLayout(service).apply { orientation = LinearLayout.HORIZONTAL }
        val segments = (1..5).map {
            View(service).also { seg ->
                meterRow.addView(
                    seg,
                    LinearLayout.LayoutParams(0, dp(5), 1f).apply { if (it > 1) marginStart = dp(4) },
                )
            }
        }
        fun stat(label: String): Triple<LinearLayout, TextView, TextView> {
            val value = TextView(service).apply {
                setTextColor(white)
                typeface = bold
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 17f)
            }
            val caption = TextView(service).apply {
                text = label
                setTextColor(muted)
                typeface = regular
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11f)
            }
            val box = LinearLayout(service).apply {
                orientation = LinearLayout.VERTICAL
                addView(value)
                addView(caption)
            }
            return Triple(box, value, caption)
        }
        val (todayBox, todayValue, _) = stat("Today")
        val (timeBox, timeValue, _) = stat("Time")
        val (passBox, passValue, _) = stat("Break left")
        passBox.visibility = View.GONE
        val statsRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(todayBox, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(timeBox, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(passBox, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        }
        val primary = TextView(service).apply {
            setTextColor(color(R.color.scroll_island_ink))
            typeface = medium
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15f)
            gravity = Gravity.CENTER
            background = roundRect(color(R.color.scroll_island_accent), dp(24).toFloat())
            isClickable = true
            isFocusable = true
            setOnClickListener {
                collapse(instant = true)
                if (IslandCardSpec.primaryAction(host.cardState()) == IslandCardAction.END_BREAK) {
                    host.onEndBreakEarly()
                } else {
                    host.onTakeBreak()
                }
            }
        }
        val close = TextView(service).apply {
            text = "Close"
            setTextColor(muted)
            typeface = medium
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15f)
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
            setOnClickListener { collapse() }
        }
        val buttons = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(primary, LinearLayout.LayoutParams(0, dp(48), 1.7f))
            addView(close, LinearLayout.LayoutParams(0, dp(48), 1f))
        }
        val bodyView = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(6), dp(20), dp(16))
            visibility = View.GONE
            addView(topRow)
            addView(meterRow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(5)).apply { topMargin = dp(14) })
            addView(statsRow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(16) })
            addView(buttons, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(16) })
        }

        // ---- surface: the black rounded shape that morphs between pill and card
        val surfaceView = FrameLayout(service).apply {
            background = roundRect(color(R.color.scroll_island_bg), l.heightPx / 2f)
            clipToOutline = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setOnClickListener {
                if (!animating && !isExpanded) {
                    performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    expand()
                }
            }
        }
        surfaceView.addView(
            head,
            FrameLayout.LayoutParams(l.widthPx, l.heightPx, Gravity.TOP or Gravity.CENTER_HORIZONTAL),
        )
        head.setOnClickListener {
            if (animating) return@setOnClickListener
            if (isExpanded) collapse() else expand()
        }
        surfaceView.addView(
            bodyView,
            FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL)
                .apply { topMargin = l.heightPx },
        )

        val rootView = FrameLayout(service)
        rootView.addView(surfaceView, FrameLayout.LayoutParams(l.widthPx, l.heightPx, Gravity.TOP or Gravity.CENTER_HORIZONTAL))
        rootView.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE && isExpanded && !animating) collapse()
            false
        }

        surface = surfaceView
        header = head
        body = bodyView
        countView = countText
        dotView = dot
        litView = lit
        timerView = timer
        bigCount = big
        moodChip = chip
        meter = segments
        statToday = todayValue
        statTime = timeValue
        statPassBox = passBox
        statPass = passValue
        primaryButton = primary
        return rootView
    }

    /** Collapsed pill: number, mood dot, and Lit or the break countdown. */
    private fun render() {
        countView?.text = count.toString()
        val alarming = ScrollMoodLevel.isAlarming(level)
        val moodColor = color(if (alarming) R.color.scroll_island_alarm else R.color.scroll_island_accent)
        (dotView?.background as? GradientDrawable)?.setColor(moodColor)

        val remaining = host.passRemainingMs()
        val timer = timerView
        val lit = litView
        if (remaining != null) {
            timer?.text = IslandCardSpec.formatCountdown(remaining)
            timer?.visibility = View.VISIBLE
            lit?.visibility = View.INVISIBLE
        } else {
            timer?.visibility = View.GONE
            lit?.visibility = View.VISIBLE
        }
        surface?.contentDescription = "Scroll damage, $count this session. Double tap for details."
    }

    /** Expanded card: fresh numbers from the host. */
    private fun fillBody() {
        val state = host.cardState()
        val alarming = ScrollMoodLevel.isAlarming(state.moodLevel)
        val moodColor = color(if (alarming) R.color.scroll_island_alarm else R.color.scroll_island_accent)

        bigCount?.text = state.sessionCount.toString()
        moodChip?.apply {
            text = IslandCardSpec.moodLabel(state.moodLevel)
            setTextColor(moodColor)
            background = roundRect((moodColor and 0x00FFFFFF) or 0x33000000, dp(14).toFloat())
        }
        val track = color(R.color.scroll_card_track)
        meter.forEachIndexed { i, seg ->
            seg.background = roundRect(if (i < state.moodLevel) moodColor else track, dp(3).toFloat())
        }
        statToday?.text = state.todayTotal.toString()
        statTime?.text = IslandCardSpec.formatMinutes(state.sessionMinutes)
        val pass = state.passRemainingMs
        statPassBox?.visibility = if (pass != null) View.VISIBLE else View.GONE
        if (pass != null) statPass?.text = IslandCardSpec.formatCountdown(pass)
        primaryButton?.text = IslandCardSpec.primaryLabel(state)
    }

    // ------------------------------------------------------------------ motion

    private fun animationsOn(): Boolean =
        Settings.Global.getFloat(service.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) != 0f

    private fun expand() {
        if (root == null || isExpanded || animating) return
        fillBody()
        val bodyView = body ?: return
        val l = layout ?: return
        // Measure the card's height from its content at the final width.
        bodyView.layoutParams = (bodyView.layoutParams as FrameLayout.LayoutParams).apply { width = cardWidthPx }
        bodyView.visibility = View.INVISIBLE
        bodyView.measure(
            View.MeasureSpec.makeMeasureSpec(cardWidthPx, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        cardHeightPx = l.heightPx + bodyView.measuredHeight
        runMorph(expanding = true, instant = false)
    }

    /**
     * Pill <-> card. The window is resized once, the surface animates inside it:
     * - expanding: resize the window to the card size (surface hidden for that one frame), then animate
     * - collapsing: animate, then resize the window back to the pill size
     */
    private fun runMorph(expanding: Boolean, instant: Boolean) {
        val view = root ?: return
        val l = layout ?: return
        val surfaceView = surface ?: return
        val headerView = header ?: return
        val bodyView = body ?: return
        animating = true
        isExpanded = expanding
        handler.removeCallbacks(autoCollapse)
        val mine = ++generation

        val pillW = l.widthPx
        val pillH = l.heightPx
        val shift = l.xOffsetPx.toFloat()
        val pillRadius = pillH / 2f
        val cardRadius = dp(28).toFloat()

        fun apply(t: Float) {
            val w = (pillW + (cardWidthPx - pillW) * t).toInt()
            val h = (pillH + (cardHeightPx - pillH) * t).toInt()
            surfaceView.layoutParams = (surfaceView.layoutParams as FrameLayout.LayoutParams).apply {
                width = w
                height = h
            }
            (surfaceView.background as? GradientDrawable)?.cornerRadius = pillRadius + (cardRadius - pillRadius) * t
            // Keep the pill header where the camera is while the surface re-centres on the screen.
            surfaceView.translationX = shift * (1f - t)
            headerView.translationX = shift * t
            bodyView.alpha = ((t - 0.25f) / 0.75f).coerceIn(0f, 1f)
        }

        fun finishExpanded() {
            if (generation != mine) return
            animating = false
            apply(1f)
            handler.postDelayed(autoCollapse, AUTO_COLLAPSE_MS)
            scheduleTickIfNeeded()
        }

        fun finishCollapsed() {
            if (generation != mine) return
            // Window back to exactly the pill; same one-frame hide so nothing jumps.
            surfaceView.alpha = 0f
            windowManager.updateViewLayout(view, params(pillW, pillH, l.xOffsetPx, l.yPx))
            afterWindowResize(view) {
                if (generation != mine) return@afterWindowResize
                bodyView.visibility = View.GONE
                surfaceView.layoutParams = (surfaceView.layoutParams as FrameLayout.LayoutParams).apply {
                    width = pillW
                    height = pillH
                }
                (surfaceView.background as? GradientDrawable)?.cornerRadius = pillRadius
                surfaceView.translationX = 0f
                headerView.translationX = 0f
                surfaceView.alpha = 1f
                animating = false
                scheduleTickIfNeeded()
            }
        }

        fun play(from: Float, to: Float, onEnd: () -> Unit) {
            if (instant || !animationsOn()) {
                apply(to)
                onEnd()
                return
            }
            morph?.cancel()
            morph = ValueAnimator.ofFloat(from, to).apply {
                duration = MORPH_MS
                // Ease-out quint: quick start, soft landing, like a spring without the overshoot.
                interpolator = PathInterpolator(0.22f, 1f, 0.36f, 1f)
                addUpdateListener { apply(it.animatedValue as Float) }
                addListener(object : android.animation.AnimatorListenerAdapter() {
                    private var cancelled = false
                    override fun onAnimationCancel(animation: android.animation.Animator) {
                        cancelled = true
                    }

                    override fun onAnimationEnd(animation: android.animation.Animator) {
                        if (!cancelled) onEnd()
                    }
                })
                start()
            }
        }

        if (expanding) {
            surfaceView.alpha = 0f
            windowManager.updateViewLayout(view, params(cardWidthPx, cardHeightPx, 0, l.yPx))
            afterWindowResize(view) {
                if (generation != mine) return@afterWindowResize
                // Surface still looks like the pill: same size, shifted back to the camera.
                apply(0f)
                bodyView.visibility = View.VISIBLE
                surfaceView.alpha = 1f
                play(0f, 1f) { finishExpanded() }
            }
        } else {
            play(1f, 0f) { finishCollapsed() }
        }
    }

    /** Runs [block] once the window has actually taken its new size (or after a short fallback). */
    private fun afterWindowResize(view: View, block: () -> Unit) {
        var done = false
        val run = {
            if (!done) {
                done = true
                block()
            }
        }
        val listener = object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                v: View, left: Int, top: Int, right: Int, bottom: Int,
                oldLeft: Int, oldTop: Int, oldRight: Int, oldBottom: Int,
            ) {
                if (right - left != oldRight - oldLeft || bottom - top != oldBottom - oldTop) {
                    v.removeOnLayoutChangeListener(this)
                    run()
                }
            }
        }
        view.addOnLayoutChangeListener(listener)
        handler.postDelayed({
            view.removeOnLayoutChangeListener(listener)
            if (root === view) run()
        }, 90)
    }

    /** Tiny scale pulse on each new item while collapsed. Skipped when animations are turned off. */
    private fun bump() {
        val view = surface ?: return
        if (animating || !animationsOn()) return
        view.animate().cancel()
        view.scaleX = 1f
        view.scaleY = 1f
        view.animate().scaleX(1.06f).scaleY(1.06f).setDuration(70).withEndAction {
            view.animate().scaleX(1f).scaleY(1f).setDuration(110).start()
        }.start()
    }

    private fun scheduleTickIfNeeded() {
        handler.removeCallbacks(tick)
        if (root != null && (isExpanded || host.passRemainingMs() != null)) {
            handler.postDelayed(tick, TICK_MS)
        }
    }

    // ------------------------------------------------------------------ display

    private fun screenSize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = windowManager.currentWindowMetrics.bounds
            return b.width() to b.height()
        }
        val m = service.resources.displayMetrics
        return m.widthPixels to m.heightPixels
    }

    private fun statusBarHeight(): Int {
        val id = service.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) service.resources.getDimensionPixelSize(id) else 0
    }

    /** Bounding rectangles of the display cutout, in screen pixels. Empty when none or unknown. */
    private fun readCutouts(attached: View?): List<PxRect> {
        return try {
            val rects: List<Rect> = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                    windowManager.currentWindowMetrics.windowInsets.displayCutout?.boundingRects.orEmpty()
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ->
                    attached?.rootWindowInsets?.displayCutout?.boundingRects.orEmpty()
                else -> emptyList()
            }
            rects.map { PxRect(it.left, it.top, it.right, it.bottom) }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
