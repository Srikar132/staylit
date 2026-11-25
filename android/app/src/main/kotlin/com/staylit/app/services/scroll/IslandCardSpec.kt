package com.staylit.app.services.scroll

/** The numbers the expanded island card shows. */
data class IslandCardState(
    val sessionCount: Int,
    val todayTotal: Int,
    val sessionMinutes: Int,
    val moodLevel: Int,
    /** Time left on a running break pass, or null when none. */
    val passRemainingMs: Long?,
)

/** What the card's main button does. */
enum class IslandCardAction { TAKE_BREAK, END_BREAK }

/**
 * Pure (no Android types) wording and formatting for the expanded island card, JVM tested.
 */
object IslandCardSpec {

    /** Same names as the Dart `ScrollMood`. Index = level - 1. */
    private val MOOD_LABELS = listOf("Calm", "Warming up", "Getting hooked", "Doomscrolling", "Meltdown")

    fun moodLabel(level: Int): String = MOOD_LABELS[(level - 1).coerceIn(0, MOOD_LABELS.lastIndex)]

    /** "0 min", "14 min", "1 h 05". */
    fun formatMinutes(minutes: Int): String {
        val m = minutes.coerceAtLeast(0)
        if (m < 60) return "$m min"
        return "${m / 60} h ${"%02d".format(m % 60)}"
    }

    /** "4:12". Rounds up so a pass never shows 0:00 while it still has time. */
    fun formatCountdown(ms: Long): String {
        val totalSeconds = ((ms.coerceAtLeast(0) + 999) / 1000).toInt()
        return "${totalSeconds / 60}:${"%02d".format(totalSeconds % 60)}"
    }

    fun primaryAction(state: IslandCardState): IslandCardAction =
        if (state.passRemainingMs != null) IslandCardAction.END_BREAK else IslandCardAction.TAKE_BREAK

    fun primaryLabel(state: IslandCardState): String =
        if (primaryAction(state) == IslandCardAction.END_BREAK) "End break early" else "Take a break"

    /** Whole minutes since the session started, never negative. */
    fun sessionMinutes(startedMs: Long, nowMs: Long): Int =
        (((nowMs - startedMs).coerceAtLeast(0)) / 60_000).toInt()
}
