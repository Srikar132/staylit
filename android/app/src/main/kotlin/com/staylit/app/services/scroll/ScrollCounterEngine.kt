package com.staylit.app.services.scroll

import kotlin.math.abs

/**
 * Pure (no Android types) swipe counter for Scroll damage.
 *
 * Feed it only numbers from `TYPE_VIEW_SCROLLED` events (page indexes and scroll delta) through
 * [onScroll]. A swipe is a burst of events; the caller re-arms a quiet timer ([Config.debounceMs])
 * on each one and calls [onSettle] when it expires. Nothing on screen is ever passed in: text,
 * ids and URLs never reach this class.
 *
 * All the tunable constants are in [Config] so they can be adjusted after device testing.
 */
class ScrollCounterEngine(
    private val config: Config = Config(),
    /** Local day key (`yyyy-MM-dd`) for a wall-clock time. */
    private val dayKeyOf: (Long) -> String = { ScrollDayKey.of(it) },
    /** Time zone offset in minutes for a wall-clock time. */
    private val tzOffsetOf: (Long) -> Int = { ScrollDayKey.offsetMinutes(it) },
) {

    data class Config(
        /** Quiet time after the last scroll event before a swipe counts as settled. */
        val debounceMs: Long = 350,
        /** Two items closer together than this are treated as scroll jitter. */
        val minItemGapMs: Long = 400,
        /** No short-form activity for this long ends a session. */
        val sessionGapMs: Long = 60_000,
        /** Fallback when the app reports no page index: minimum total |scrollDeltaY| of a swipe. */
        val minDeltaPx: Int = 200,
    )

    enum class Outcome { COUNTED, NOT_SHORT_FORM, SAME_PAGE, TOO_FAST, NO_BURST }

    data class Result(
        val outcome: Outcome,
        val day: String = "",
        val tzOffsetMinutes: Int = 0,
        /** True when this item opened a new session (so the day's session count goes up). */
        val newSession: Boolean = false,
        /** Items in the current session, including this one. */
        val sessionCount: Int = 0,
    )

    // Current burst (one swipe).
    private var burstPkg: String? = null
    private var burstFirstFrom = -1
    private var burstLastFrom = -1
    private var burstAbsDy = 0
    private var burstEvents = 0

    // Between swipes.
    private var lastIndex: Int? = null
    private var lastCountedMs = NEVER
    private var lastActiveMs = NEVER
    private var sessionOpen = false
    private var sessionItems = 0

    /** Package of the swipe in progress, or null when no burst is open. */
    val burstPackage: String? get() = burstPkg

    /** Items counted in the current session (resets when a new one starts). */
    val currentSessionCount: Int get() = sessionItems

    /**
     * One scroll event. [fromIndex] is the event's first visible item index, or -1 when the app
     * does not report one. [deltaY] is 0 when unknown (API < 28).
     */
    fun onScroll(pkg: String, fromIndex: Int, deltaY: Int) {
        if (burstPkg != null && burstPkg != pkg) clearBurst()
        if (burstEvents == 0) {
            burstPkg = pkg
            burstFirstFrom = fromIndex
        }
        burstLastFrom = fromIndex
        burstAbsDy += abs(deltaY)
        burstEvents++
    }

    /**
     * The swipe went quiet. [nowMs] is a monotonic clock (for gaps), [wallMs] the wall clock (for the
     * day key). [shortFormActive] says whether the short-form view of the app is the one on screen.
     */
    fun onSettle(nowMs: Long, wallMs: Long, shortFormActive: Boolean): Result {
        val pkg = burstPkg
        if (pkg == null || burstEvents == 0) return Result(Outcome.NO_BURST)

        val firstFrom = burstFirstFrom
        val lastFrom = burstLastFrom
        val absDy = burstAbsDy
        clearBurst()

        if (!shortFormActive) {
            // Left the short-form view: the next one starts from a fresh page baseline.
            lastIndex = null
            return Result(Outcome.NOT_SHORT_FORM)
        }

        if (lastActiveMs == NEVER || nowMs - lastActiveMs > config.sessionGapMs) {
            sessionOpen = false
        }
        lastActiveMs = nowMs

        val indexKnown = lastFrom >= 0
        val changed = if (indexKnown) {
            val baseline = lastIndex ?: firstFrom
            lastFrom != baseline
        } else {
            absDy >= config.minDeltaPx
        }
        if (indexKnown) lastIndex = lastFrom

        if (!changed) return Result(Outcome.SAME_PAGE)
        if (lastCountedMs != NEVER && nowMs - lastCountedMs < config.minItemGapMs) {
            return Result(Outcome.TOO_FAST)
        }

        lastCountedMs = nowMs
        var newSession = false
        if (!sessionOpen) {
            sessionOpen = true
            sessionItems = 0
            newSession = true
        }
        sessionItems++
        return Result(
            outcome = Outcome.COUNTED,
            day = dayKeyOf(wallMs),
            tzOffsetMinutes = tzOffsetOf(wallMs),
            newSession = newSession,
            sessionCount = sessionItems,
        )
    }

    /** Counting stopped (feature turned off, service unbound): forget everything in flight. */
    fun reset() {
        clearBurst()
        lastIndex = null
        lastCountedMs = NEVER
        lastActiveMs = NEVER
        sessionOpen = false
        sessionItems = 0
    }

    private fun clearBurst() {
        burstPkg = null
        burstFirstFrom = -1
        burstLastFrom = -1
        burstAbsDy = 0
        burstEvents = 0
    }

    private companion object {
        const val NEVER = Long.MIN_VALUE
    }
}
