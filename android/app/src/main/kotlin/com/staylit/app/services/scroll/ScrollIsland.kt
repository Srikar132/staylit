package com.staylit.app.services.scroll

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.staylit.app.R

/**
 * The "dynamic island": a small black pill at the top of the screen, placed around the camera cutout with
 * the DisplayCutout API, showing the live session count next to a tiny Lit.
 *
 * It is an accessibility overlay window (no extra permission) that never takes touches or focus, so it
 * cannot block a swipe. It shows only our own number, nothing from the screen. All placement maths is in
 * the pure [IslandGeometry].
 */
class ScrollIsland(private val service: AccessibilityService) {

    private companion object {
        const val TAG = "ScrollDamage"
    }

    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val density get() = service.resources.displayMetrics.density

    private var root: LinearLayout? = null
    private var countView: TextView? = null
    private var dotView: View? = null
    private var layout: IslandLayout? = null

    /** The caller wants the pill visible (so it can come back after a rotation). */
    private var wanted = false
    private var count = 0
    private var level = 1

    /** A failed add (bad token, OEM restriction) turns the island off for the session, never crashes. */
    private var failed = false

    val isShown: Boolean get() = root != null

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
        bump()
    }

    fun hide() {
        wanted = false
        remove()
    }

    /** Rotation, fold/unfold, display size or font scale changed: place the pill again. */
    fun onConfigurationChanged() {
        if (!wanted) return
        remove()
        attach(null)
    }

    // ---- window

    private fun attach(cutoutsOverride: List<PxRect>?) {
        if (failed || root != null) return
        try {
            val (screenW, screenH) = screenSize()
            val cutouts = cutoutsOverride ?: readCutouts(null)
            val l = IslandGeometry.compute(screenW, screenH, density, cutouts, statusBarHeight()) ?: return
            val view = buildView(l)

            val params = WindowManager.LayoutParams(
                l.widthPx,
                l.heightPx,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                x = l.xOffsetPx
                y = l.yPx
                // Let the pill draw into the cutout area itself.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }

            windowManager.addView(view, params)
            root = view
            layout = l
            render()

            // API 28-29 only expose the cutout once a view is attached: place again if it differs.
            view.post { refine(view) }
        } catch (e: Exception) {
            failed = true
            root = null
            Log.e(TAG, "island add failed, island off for this session", e)
        }
    }

    private fun refine(view: View) {
        if (root !== view || !wanted) return
        val cutouts = readCutouts(view)
        val (screenW, screenH) = screenSize()
        val better = IslandGeometry.compute(screenW, screenH, density, cutouts, statusBarHeight())
        if (better != null && better != layout) {
            remove()
            attach(cutouts)
        }
    }

    private fun remove() {
        val view = root ?: return
        root = null
        countView = null
        dotView = null
        layout = null
        try {
            windowManager.removeViewImmediate(view)
        } catch (e: Exception) {
            // Already gone (service restarted): nothing to clean up.
        }
    }

    // ---- view

    private fun dp(v: Int) = (v * density).toInt()

    private fun buildView(l: IslandLayout): LinearLayout {
        val bg = GradientDrawable().apply {
            setColor(service.getColor(R.color.scroll_island_bg))
            cornerRadius = l.heightPx / 2f
        }
        val dot = View(service).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL }
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(8)).apply { marginEnd = dp(6) }
        }
        val countText = TextView(service).apply {
            setTextColor(service.getColor(R.color.scroll_island_text))
            // dp, not sp: the pill must never outgrow the cutout height when the font is scaled up.
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15f)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            includeFontPadding = false
            gravity = Gravity.CENTER_VERTICAL
        }
        val lit = ImageView(service).apply {
            setImageResource(R.drawable.lit_scroll_pill)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(dp(22), dp(22))
        }

        val row = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = bg
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        if (l.wrapsCutout) {
            val side = (l.widthPx - l.cutoutWidthPx) / 2
            val left = LinearLayout(service).apply {
                gravity = Gravity.CENTER
                addView(dot)
                addView(countText)
            }
            val right = LinearLayout(service).apply {
                gravity = Gravity.CENTER
                addView(lit)
            }
            row.addView(left, LinearLayout.LayoutParams(side, LinearLayout.LayoutParams.MATCH_PARENT))
            // The camera hole sits in this gap, in the pill's black middle.
            row.addView(View(service), LinearLayout.LayoutParams(l.cutoutWidthPx, 1))
            row.addView(right, LinearLayout.LayoutParams(side, LinearLayout.LayoutParams.MATCH_PARENT))
        } else {
            row.gravity = Gravity.CENTER
            row.addView(dot)
            row.addView(countText)
            row.addView(lit, LinearLayout.LayoutParams(dp(22), dp(22)).apply { marginStart = dp(8) })
        }

        countView = countText
        dotView = dot
        return row
    }

    private fun render() {
        countView?.text = count.toString()
        val color = if (ScrollMoodLevel.isAlarming(level)) R.color.scroll_island_alarm else R.color.scroll_island_accent
        (dotView?.background as? GradientDrawable)?.setColor(service.getColor(color))
    }

    /** Tiny scale pulse on each new item. Skipped when animations are turned off. */
    private fun bump() {
        val view = root ?: return
        val scale = Settings.Global.getFloat(service.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
        if (scale == 0f) return
        view.animate().cancel()
        view.scaleX = 1f
        view.scaleY = 1f
        view.animate().scaleX(1.06f).scaleY(1.06f).setDuration(70).withEndAction {
            view.animate().scaleX(1f).scaleY(1f).setDuration(110).start()
        }.start()
    }

    // ---- display

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
