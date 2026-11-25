package com.staylit.app.services.scroll

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat
import com.staylit.app.R

/**
 * The Lit sheet: one good-looking bottom card used for the scroll "Take a break?" offer, the short-form
 * "blocked" screen and "Time's up". Built from the pure [SheetSpec], styled with the Warm Focus tokens
 * (light and dark follow the system), Space Grotesk, rounded shapes, one orange pill per sheet.
 *
 * It is an accessibility overlay window: instant (no Flutter engine start) and it needs no extra
 * permission. Modal sheets dim the screen and take touches; the offer is a card the app stays usable
 * around. Text is our own copy only, nothing from the screen.
 */
class LitSheet(private val service: AccessibilityService) {

    enum class Kind { PRIMARY, SECONDARY, PASS, TIMEOUT, LEFT }

    data class Result(val kind: Kind, val minutes: Int = 0)

    private companion object {
        const val TAG = "ScrollDamage"
        const val MAX_CARD_WIDTH_DP = 420
    }

    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density get() = service.resources.displayMetrics.density

    private var root: View? = null
    private var onResult: ((Result) -> Unit)? = null
    private var timeout: Runnable? = null

    var mode: SheetMode? = null
        private set

    val isShown: Boolean get() = root != null

    /**
     * Shows [spec]. [onResult] is called exactly once: with the user's choice, or [Kind.TIMEOUT] after
     * [autoDismissMs] (0 = never auto-dismiss). Returns false if it could not be shown.
     */
    fun show(spec: SheetSpec, litRes: Int, autoDismissMs: Long, onResult: (Result) -> Unit): Boolean {
        if (root != null) return false
        colors = themedContext()
        return try {
            val card = buildCard(spec, litRes)
            val view = if (spec.modal) buildModalRoot(card) else card
            windowManager.addView(view, layoutParams(spec.modal))
            root = view
            mode = spec.mode
            this.onResult = onResult
            if (autoDismissMs > 0) {
                timeout = Runnable { answer(Result(Kind.TIMEOUT)) }.also { handler.postDelayed(it, autoDismissMs) }
            }
            slideIn(card)
            view.post {
                card.announceForAccessibility(spec.title + ". " + spec.body)
            }
            true
        } catch (e: Exception) {
            root = null
            mode = null
            Log.e(TAG, "sheet add failed", e)
            false
        }
    }

    /** Ends the sheet with [result] (once). Safe to call when it is not shown. */
    fun answer(result: Result) {
        val callback = onResult ?: return
        onResult = null
        remove()
        callback(result)
    }

    /** Removes the sheet without reporting anything (service stopping, feature turned off). */
    fun dismissSilently() {
        onResult = null
        remove()
    }

    private fun remove() {
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        val view = root ?: return
        root = null
        mode = null
        try {
            windowManager.removeViewImmediate(view)
        } catch (e: Exception) {
            // Already gone.
        }
    }

    // ---- window

    private fun layoutParams(modal: Boolean): WindowManager.LayoutParams {
        val metrics = service.resources.displayMetrics
        return if (modal) {
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            )
        } else {
            WindowManager.LayoutParams(
                cardWidth(metrics.widthPixels),
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                // Float above the app's own bottom bar and the system nav bar.
                y = navInset() + dp(72)
            }
        }
    }

    private fun cardWidth(screenWidthPx: Int) = minOf(screenWidthPx - dp(40), dp(MAX_CARD_WIDTH_DP))

    private fun navInset(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return try {
                windowManager.currentWindowMetrics.windowInsets
                    .getInsets(WindowInsets.Type.navigationBars()).bottom
            } catch (e: Exception) {
                0
            }
        }
        val id = service.resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (id > 0) service.resources.getDimensionPixelSize(id) else 0
    }

    private fun dp(v: Int) = (v * density).toInt()

    // ---- views

    private fun font(res: Int): Typeface = try {
        ResourcesCompat.getFont(service, res) ?: Typeface.DEFAULT
    } catch (e: Exception) {
        Typeface.DEFAULT
    }

    /** Resources resolved for the app's own Appearance (Light / Dark), not necessarily the system theme. */
    private var colors: Context = service

    private fun themedContext(): Context {
        val mode = service.getSharedPreferences("app_appearance", Context.MODE_PRIVATE).getString("mode", "system")
        val night = when (mode) {
            "light" -> Configuration.UI_MODE_NIGHT_NO
            "dark" -> Configuration.UI_MODE_NIGHT_YES
            else -> return service // "System": follow the phone
        }
        return try {
            val config = Configuration(service.resources.configuration)
            config.uiMode = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
            service.createConfigurationContext(config)
        } catch (e: Exception) {
            service
        }
    }

    private fun color(res: Int) = colors.getColor(res)

    private fun pill(fill: Int, radiusDp: Int = 28): GradientDrawable = GradientDrawable().apply {
        setColor(fill)
        cornerRadius = dp(radiusDp).toFloat()
    }

    private fun ripple(content: GradientDrawable): RippleDrawable =
        RippleDrawable(ColorStateList.valueOf(0x22000000), content, null)

    private fun buildModalRoot(card: View): FrameLayout {
        val metrics = service.resources.displayMetrics
        val frame = FrameLayout(service).apply {
            setBackgroundColor(color(R.color.lit_scrim))
            // The scrim eats touches so nothing underneath reacts while a choice is pending.
            isClickable = true
        }
        frame.addView(
            card,
            FrameLayout.LayoutParams(cardWidth(metrics.widthPixels), FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                bottomMargin = navInset() + dp(16)
            },
        )
        return frame
    }

    private fun buildCard(spec: SheetSpec, litRes: Int): LinearLayout {
        val regular = font(R.font.space_grotesk_regular)
        val medium = font(R.font.space_grotesk_medium)
        val bold = font(R.font.space_grotesk_bold)

        val lit = ImageView(service).apply {
            try {
                setImageResource(litRes)
            } catch (e: Exception) {
                // Missing or undecodable image: the sheet still works as text.
            }
            scaleType = ImageView.ScaleType.FIT_CENTER
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val title = TextView(service).apply {
            text = spec.title
            typeface = bold
            setTextColor(color(R.color.lit_text))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            gravity = Gravity.CENTER
        }
        val body = TextView(service).apply {
            text = spec.body
            typeface = regular
            setTextColor(color(R.color.lit_text_secondary))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
        }

        val card = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(20), dp(24), dp(20))
            background = pill(color(R.color.lit_card))
            accessibilityPaneTitle = spec.title
        }
        card.addView(lit, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(88)))
        card.addView(title, lp(top = 12))
        card.addView(body, lp(top = 8))

        // The one orange pill of the sheet.
        val primary = TextView(service).apply {
            text = spec.primaryLabel
            typeface = medium
            setTextColor(color(R.color.lit_on_accent))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            background = ripple(pill(color(R.color.lit_accent)))
            isClickable = true
            isFocusable = true
            minimumHeight = dp(56)
            setOnClickListener { answer(Result(Kind.PRIMARY)) }
        }
        card.addView(primary, lp(top = 20, height = 56))

        spec.secondaryLabel?.let { label ->
            val secondary = TextView(service).apply {
                text = label
                typeface = medium
                setTextColor(color(R.color.lit_text_secondary))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                gravity = Gravity.CENTER
                isClickable = true
                isFocusable = true
                setOnClickListener { answer(Result(Kind.SECONDARY)) }
            }
            card.addView(secondary, lp(top = 4, height = 48))
        }

        if (spec.passMinutes.isNotEmpty()) {
            val label = TextView(service).apply {
                text = "Need a breather?"
                typeface = medium
                setTextColor(color(R.color.lit_text_muted))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                gravity = Gravity.CENTER
            }
            card.addView(label, lp(top = 20))
            card.addView(buildChips(spec.passMinutes, bold, regular), lp(top = 10))
        } else if (spec.hint != null) {
            val hint = TextView(service).apply {
                text = spec.hint
                typeface = regular
                setTextColor(color(R.color.lit_text_muted))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                gravity = Gravity.CENTER
            }
            card.addView(hint, lp(top = 16))
        }
        return card
    }

    /** "5 min  10 min  20 min": bold numerals, small units (the design system's duration pattern). */
    private fun buildChips(minutes: List<Int>, bold: Typeface, regular: Typeface): LinearLayout {
        val row = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            weightSum = minutes.size.toFloat()
        }
        for ((i, m) in minutes.withIndex()) {
            val text = SpannableString("$m min").apply {
                setSpan(RelativeSizeSpan(0.6f), "$m".length, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            val chip = TextView(service).apply {
                this.text = text
                contentDescription = "Watch for $m minutes"
                typeface = bold
                setTextColor(color(R.color.lit_text))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                gravity = Gravity.CENTER
                background = ripple(pill(color(R.color.lit_chip), radiusDp = 26))
                isClickable = true
                isFocusable = true
                setOnClickListener { answer(Result(Kind.PASS, m)) }
            }
            row.addView(
                chip,
                LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                    if (i > 0) marginStart = dp(8)
                },
            )
        }
        return row
    }

    private fun lp(top: Int = 0, height: Int = LinearLayout.LayoutParams.WRAP_CONTENT) =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            if (height > 0) dp(height) else height,
        ).apply { topMargin = dp(top) }

    // ---- motion

    private fun animationsOn(): Boolean =
        Settings.Global.getFloat(service.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) != 0f

    private fun slideIn(card: View) {
        if (!animationsOn()) return
        card.alpha = 0f
        card.post {
            card.translationY = card.height * 0.35f
            card.animate().translationY(0f).alpha(1f).setDuration(260)
                .setInterpolator(DecelerateInterpolator(1.6f)).start()
        }
    }
}
