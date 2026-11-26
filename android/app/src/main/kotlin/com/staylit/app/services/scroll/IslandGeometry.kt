package com.staylit.app.services.scroll

import kotlin.math.abs
import kotlin.math.max

/**
 * Pure (no Android types) placement of the Scroll damage "island" pill from the display cutout.
 * Kept framework-free so every cutout shape can be unit tested on the JVM with synthetic rectangles.
 */

data class PxRect(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    val width: Int get() = right - left
    val height: Int get() = bottom - top
    val centerX: Int get() = (left + right) / 2
}

data class IslandLayout(
    val widthPx: Int,
    val heightPx: Int,
    /** Horizontal offset of the pill's centre from the screen centre (gravity TOP | CENTER_HORIZONTAL). */
    val xOffsetPx: Int,
    val yPx: Int,
    /** True when the pill wraps a centred camera cutout (count on the left, Lit on the right). */
    val wrapsCutout: Boolean,
    /** Width of each side segment when [wrapsCutout]; the camera sits in the gap between them. */
    val cutoutWidthPx: Int,
)

object IslandGeometry {

    private const val SIDE_SEGMENT_DP = 52
    private const val COMPACT_WIDTH_DP = 96
    private const val MIN_HEIGHT_DP = 28
    private const val COMPACT_GAP_DP = 4
    private const val CUTOUT_EXTRA_DP = 2

    /** A cutout whose centre is within this share of the screen width from the middle counts as centred. */
    private const val CENTRED_TOLERANCE = 0.12f

    /** A cutout wider than this share of the screen is too big to wrap: sit below it instead. */
    private const val MAX_WRAP_SHARE = 0.45f

    /**
     * @param cutouts bounding rectangles of the display cutout in screen pixels (may be empty)
     * @param statusBarHeightPx height of the status bar, 0 if unknown
     * @return null when the pill should not be shown at all (landscape)
     */
    fun compute(
        screenWidthPx: Int,
        screenHeightPx: Int,
        density: Float,
        cutouts: List<PxRect>,
        statusBarHeightPx: Int,
    ): IslandLayout? {
        if (screenWidthPx <= 0 || screenHeightPx <= 0 || density <= 0f) return null
        if (screenWidthPx > screenHeightPx) return null // landscape

        fun dp(v: Int) = (v * density).toInt()

        // Only cutouts at the top edge matter (a bottom or side cutout never touches the pill).
        val top = cutouts.filter { it.top <= 0 && it.bottom > 0 && it.bottom < screenHeightPx / 4 }
        val screenCentre = screenWidthPx / 2

        val centred = top
            .filter { abs(it.centerX - screenCentre) <= screenWidthPx * CENTRED_TOLERANCE }
            .minByOrNull { abs(it.centerX - screenCentre) }

        if (centred != null && centred.width <= screenWidthPx * MAX_WRAP_SHARE) {
            val side = dp(SIDE_SEGMENT_DP)
            return IslandLayout(
                widthPx = (centred.width + 2 * side).coerceAtMost((screenWidthPx * 0.8f).toInt()),
                heightPx = max(centred.bottom + dp(CUTOUT_EXTRA_DP), dp(MIN_HEIGHT_DP)),
                xOffsetPx = centred.centerX - screenCentre,
                yPx = 0,
                wrapsCutout = true,
                cutoutWidthPx = centred.width,
            )
        }

        // Compact pill, centred, below the status bar and below any cutout it would overlap.
        val width = dp(COMPACT_WIDTH_DP)
        val height = dp(MIN_HEIGHT_DP)
        val left = screenCentre - width / 2
        val right = left + width
        var y = statusBarHeightPx.coerceAtLeast(0)
        for (rect in top) {
            if (rect.right > left && rect.left < right) y = max(y, rect.bottom)
        }
        return IslandLayout(
            widthPx = width,
            heightPx = height,
            xOffsetPx = 0,
            yPx = y + dp(COMPACT_GAP_DP),
            wrapsCutout = false,
            cutoutWidthPx = 0,
        )
    }
}
