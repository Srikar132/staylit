package com.staylit.app.services.scroll

/**
 * Native twin of the Dart `ScrollMood` (lib/presentation/screens/focus/scroll_mood.dart): the same
 * thresholds, so the Home card and the on-screen pill agree. A test pins the values; if you change one
 * side, change the other.
 */
object ScrollMoodLevel {
    /** Upper bounds (exclusive) of mood levels 1..4; anything above is level 5. */
    val THRESHOLDS = intArrayOf(20, 60, 120, 200)

    /** 1 (calm) to 5 (meltdown). */
    fun forCount(count: Int): Int {
        val safe = if (count < 0) 0 else count
        for (i in THRESHOLDS.indices) {
            if (safe < THRESHOLDS[i]) return i + 1
        }
        return THRESHOLDS.size + 1
    }

    /** Levels 4 and 5 are drawn in the error colour, like the Home card meter. */
    fun isAlarming(level: Int): Boolean = level >= 4
}
