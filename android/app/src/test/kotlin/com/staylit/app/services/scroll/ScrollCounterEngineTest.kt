package com.staylit.app.services.scroll

import com.staylit.app.services.scroll.ScrollCounterEngine.Outcome
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScrollCounterEngineTest {

    private val pkg = "com.instagram.android"

    // Wall clock = monotonic clock here; day key is just a label we can control.
    private var day = "2026-11-25"
    private val engine = ScrollCounterEngine(
        dayKeyOf = { day },
        tzOffsetOf = { 330 },
    )

    /** One swipe that lands on [index], settled at [at]. */
    private fun swipe(index: Int, at: Long, from: Int = index - 1, active: Boolean = true): ScrollCounterEngine.Result {
        engine.onScroll(pkg, from, deltaY = 600)
        engine.onScroll(pkg, index, deltaY = 100)
        return engine.onSettle(at, at, active)
    }

    @Test
    fun `settle with no events does nothing`() {
        assertEquals(Outcome.NO_BURST, engine.onSettle(0, 0, true).outcome)
    }

    @Test
    fun `first swipe counts because it moved off the starting page`() {
        val r = swipe(index = 1, at = 1_000)
        assertEquals(Outcome.COUNTED, r.outcome)
        assertTrue(r.newSession)
        assertEquals(1, r.sessionCount)
        assertEquals("2026-11-25", r.day)
        assertEquals(330, r.tzOffsetMinutes)
    }

    @Test
    fun `twenty swipes count twenty`() {
        var counted = 0
        for (i in 1..20) {
            if (swipe(index = i, at = i * 1_000L).outcome == Outcome.COUNTED) counted++
        }
        assertEquals(20, counted)
        assertEquals(20, engine.currentSessionCount)
    }

    @Test
    fun `events on the same page are not an item`() {
        swipe(index = 1, at = 1_000)
        // Bounce / comment-style jitter that ends on the same page.
        engine.onScroll(pkg, 1, deltaY = 40)
        engine.onScroll(pkg, 1, deltaY = -40)
        assertEquals(Outcome.SAME_PAGE, engine.onSettle(2_000, 2_000, true).outcome)
    }

    @Test
    fun `many events in one swipe count once`() {
        engine.onScroll(pkg, 4, deltaY = 50)
        repeat(12) { engine.onScroll(pkg, 4, deltaY = 80) }
        engine.onScroll(pkg, 5, deltaY = 10)
        assertEquals(Outcome.COUNTED, engine.onSettle(1_000, 1_000, true).outcome)
        assertEquals(1, engine.currentSessionCount)
    }

    @Test
    fun `a change faster than the gap is jitter`() {
        assertEquals(Outcome.COUNTED, swipe(index = 1, at = 1_000).outcome)
        assertEquals(Outcome.TOO_FAST, swipe(index = 2, at = 1_200).outcome)
        // The index baseline moved on, so the same page is not counted again later.
        assertEquals(Outcome.COUNTED, swipe(index = 3, at = 2_000).outcome)
    }

    @Test
    fun `not in the short form view is rejected and resets the baseline`() {
        assertEquals(Outcome.NOT_SHORT_FORM, swipe(index = 7, at = 1_000, active = false).outcome)
        assertEquals(0, engine.currentSessionCount)
        // Back in reels at a far page: counts relative to the first event of the burst, not the old page.
        val r = swipe(index = 3, at = 5_000, from = 2)
        assertEquals(Outcome.COUNTED, r.outcome)
    }

    @Test
    fun `no index falls back to scroll distance`() {
        engine.onScroll(pkg, -1, deltaY = 150)
        assertEquals(Outcome.SAME_PAGE, engine.onSettle(1_000, 1_000, true).outcome)
        engine.onScroll(pkg, -1, deltaY = 150)
        engine.onScroll(pkg, -1, deltaY = -120)
        assertEquals(Outcome.COUNTED, engine.onSettle(2_000, 2_000, true).outcome)
    }

    @Test
    fun `a session ends after a minute without short form activity`() {
        assertTrue(swipe(index = 1, at = 1_000).newSession)
        assertFalse(swipe(index = 2, at = 2_000).newSession)
        assertEquals(2, engine.currentSessionCount)

        val later = swipe(index = 3, at = 2_000 + 61_000)
        assertTrue(later.newSession)
        assertEquals(1, later.sessionCount)
    }

    @Test
    fun `watching without swiping keeps the session alive`() {
        swipe(index = 1, at = 1_000)
        // 50 s later a settle on the same page (active, not counted), then another 50 s later.
        engine.onScroll(pkg, 1, deltaY = 5)
        assertEquals(Outcome.SAME_PAGE, engine.onSettle(51_000, 51_000, true).outcome)
        val r = swipe(index = 2, at = 101_000)
        assertEquals(Outcome.COUNTED, r.outcome)
        assertFalse(r.newSession)
    }

    @Test
    fun `day key follows the clock at the moment of counting`() {
        day = "2026-11-25"
        assertEquals("2026-11-25", swipe(index = 1, at = 1_000).day)
        day = "2026-11-26"
        val r = swipe(index = 2, at = 2_000)
        assertEquals("2026-11-26", r.day)
        // Same session across midnight: not a new session.
        assertFalse(r.newSession)
    }

    @Test
    fun `switching app clears the swipe in progress`() {
        engine.onScroll(pkg, 3, deltaY = 300)
        engine.onScroll("com.google.android.youtube", 8, deltaY = 300)
        assertEquals("com.google.android.youtube", engine.burstPackage)
    }

    @Test
    fun `reset forgets everything`() {
        swipe(index = 1, at = 1_000)
        engine.onScroll(pkg, 2, deltaY = 100)
        engine.reset()
        assertNull(engine.burstPackage)
        assertEquals(0, engine.currentSessionCount)
        assertTrue(swipe(index = 1, at = 1_100).newSession)
    }
}
