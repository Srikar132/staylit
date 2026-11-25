package com.staylit.app.services.focus

/**
 * Pure (no Android types) rule for "is this focus session's time up?", used as a safety net so a
 * session whose native timer was lost (Activity torn down, process restarted) still completes the
 * moment anything asks. JVM tested.
 */
object SessionDue {

    /** Only countdown ("timer") sessions end on their own. Stopwatch and pomodoro never auto-complete here. */
    fun isDue(sessionType: String, plannedMinutes: Int, elapsedMs: Long, paused: Boolean): Boolean =
        !paused &&
            sessionType.equals("timer", ignoreCase = true) &&
            plannedMinutes > 0 &&
            elapsedMs >= plannedMinutes * 60_000L
}
