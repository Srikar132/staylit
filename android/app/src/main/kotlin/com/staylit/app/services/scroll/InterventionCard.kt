package com.staylit.app.services.scroll

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.staylit.app.R

/**
 * The "Take a break?" card: a small bottom card with two buttons. An accessibility overlay that never
 * takes focus or the keyboard; only the card itself is touchable, so the app below keeps working.
 * Text is our own copy plus the session count, nothing from the screen.
 */
class InterventionCard(private val service: AccessibilityService) {

    private companion object {
        const val TAG = "ScrollDamage"
    }

    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val density get() = service.resources.displayMetrics.density

    private var root: View? = null
    private var onResponse: ((OfferResponse) -> Unit)? = null
    private var timeout: Runnable? = null

    val isShown: Boolean get() = root != null

    /** Shows the card. [onResponse] is called exactly once, with the user's choice or a timeout. */
    fun show(count: Int, autoDismissMs: Long, onResponse: (OfferResponse) -> Unit): Boolean {
        if (root != null) return false
        return try {
            val view = buildView(count)
            val width = service.resources.displayMetrics.widthPixels - dp(32)
            val params = WindowManager.LayoutParams(
                width,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                y = dp(96)
            }
            windowManager.addView(view, params)
            root = view
            this.onResponse = onResponse
            timeout = Runnable { answer(OfferResponse.TIMEOUT) }.also { handler.postDelayed(it, autoDismissMs) }
            view.post {
                view.announceForAccessibility(
                    service.getString(R.string.scroll_offer_title, count) + ". " +
                        service.getString(R.string.scroll_offer_question),
                )
            }
            true
        } catch (e: Exception) {
            root = null
            Log.e(TAG, "card add failed", e)
            false
        }
    }

    /** Ends the card with [response] (once). Safe to call when it is not shown. */
    fun answer(response: OfferResponse) {
        val callback = onResponse ?: return
        onResponse = null
        remove()
        callback(response)
    }

    /** Removes the card without reporting an answer (service stopping). */
    fun dismissSilently() {
        onResponse = null
        remove()
    }

    private fun remove() {
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        val view = root ?: return
        root = null
        try {
            windowManager.removeViewImmediate(view)
        } catch (e: Exception) {
            // Already gone.
        }
    }

    private fun dp(v: Int) = (v * density).toInt()

    private fun buildView(count: Int): View {
        val title = TextView(service).apply {
            text = service.getString(R.string.scroll_offer_title, count)
            setTextColor(service.getColor(R.color.scroll_island_text))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
        }
        val question = TextView(service).apply {
            text = service.getString(R.string.scroll_offer_question)
            setTextColor(service.getColor(R.color.scroll_card_muted))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        }
        val breakButton = Button(service).apply {
            text = service.getString(R.string.scroll_offer_break)
            isAllCaps = false
            setTextColor(service.getColor(R.color.scroll_island_text))
            background = GradientDrawable().apply {
                setColor(service.getColor(R.color.scroll_island_accent))
                cornerRadius = dp(24).toFloat()
            }
            setOnClickListener { answer(OfferResponse.BREAK) }
        }
        val keepButton = Button(service).apply {
            text = service.getString(R.string.scroll_offer_keep)
            isAllCaps = false
            setTextColor(service.getColor(R.color.scroll_island_text))
            background = null
            setOnClickListener { answer(OfferResponse.KEEP) }
        }
        val buttons = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            addView(keepButton)
            addView(
                breakButton,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { marginStart = dp(8) },
            )
        }
        return LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(16), dp(16), dp(12))
            background = GradientDrawable().apply {
                setColor(service.getColor(R.color.scroll_card_bg))
                cornerRadius = dp(24).toFloat()
            }
            addView(title)
            addView(question)
            addView(buttons, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(8) })
        }
    }
}
