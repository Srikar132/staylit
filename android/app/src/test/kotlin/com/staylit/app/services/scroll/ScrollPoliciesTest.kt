package com.staylit.app.services.scroll

import com.staylit.app.services.scroll.IslandPolicy.Action
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScrollMoodLevelTest {
    @Test
    fun `thresholds match the Dart ScrollMood`() {
        // lib/presentation/screens/focus/scroll_mood.dart: [20, 60, 120, 200]
        assertEquals(listOf(20, 60, 120, 200), ScrollMoodLevel.THRESHOLDS.toList())
    }

    @Test
    fun `level follows the count and never goes below one`() {
        assertEquals(1, ScrollMoodLevel.forCount(-5))
        assertEquals(1, ScrollMoodLevel.forCount(0))
        assertEquals(1, ScrollMoodLevel.forCount(19))
        assertEquals(2, ScrollMoodLevel.forCount(20))
        assertEquals(3, ScrollMoodLevel.forCount(119))
        assertEquals(4, ScrollMoodLevel.forCount(199))
        assertEquals(5, ScrollMoodLevel.forCount(200))
        assertEquals(5, ScrollMoodLevel.forCount(5000))
    }

    @Test
    fun `only the top two levels are alarming`() {
        assertFalse(ScrollMoodLevel.isAlarming(3))
        assertTrue(ScrollMoodLevel.isAlarming(4))
        assertTrue(ScrollMoodLevel.isAlarming(5))
    }
}

class IslandPolicyTest {
    private val p = IslandPolicy(minItems = 5, idleMs = 60_000)

    @Test
    fun `hidden until the fifth item, then shows and updates`() {
        for (n in 1..4) assertEquals(Action.NONE, p.onCounted(n, newSession = n == 1, nowMs = n * 1000L))
        assertEquals(Action.SHOW, p.onCounted(5, false, 5_000))
        assertTrue(p.visible)
        assertEquals(Action.UPDATE, p.onCounted(6, false, 6_000))
    }

    @Test
    fun `leaving the short form view hides it`() {
        for (n in 1..5) p.onCounted(n, n == 1, n * 1000L)
        assertEquals(Action.HIDE, p.onLeft())
        assertFalse(p.visible)
        assertEquals(Action.NONE, p.onLeft())
    }

    @Test
    fun `a new session hides the pill and waits for five items again`() {
        for (n in 1..6) p.onCounted(n, n == 1, n * 1000L)
        assertEquals(Action.HIDE, p.onCounted(1, newSession = true, nowMs = 100_000))
        assertEquals(Action.NONE, p.onCounted(2, false, 101_000))
        for (n in 3..4) p.onCounted(n, false, 102_000)
        assertEquals(Action.SHOW, p.onCounted(5, false, 103_000))
    }

    @Test
    fun `idle hides it after a minute but activity keeps it alive`() {
        for (n in 1..5) p.onCounted(n, n == 1, n * 1000L) // last activity 5 s
        assertEquals(Action.NONE, p.onIdleCheck(30_000))
        p.onActivity(50_000) // watching without swiping
        assertEquals(Action.NONE, p.onIdleCheck(100_000))
        assertEquals(Action.HIDE, p.onIdleCheck(111_000))
        assertFalse(p.visible)
    }

    @Test
    fun `idle check on a hidden pill does nothing`() {
        assertEquals(Action.NONE, p.onIdleCheck(1_000_000))
    }

    @Test
    fun `hide and reset are safe to repeat`() {
        assertEquals(Action.NONE, p.hide())
        for (n in 1..5) p.onCounted(n, n == 1, n * 1000L)
        assertEquals(Action.HIDE, p.hide())
        p.reset()
        assertFalse(p.visible)
    }
}

class InterventionPolicyTest {
    private val p = InterventionPolicy()

    private fun countTo(n: Int, startAt: Long = 0, stepMs: Long = 3_000): Boolean {
        var offer = false
        for (i in 1..n) offer = p.onCounted(i, newSession = i == 1, nowMs = startAt + i * stepMs) || offer
        return offer
    }

    @Test
    fun `no offer before the threshold, offer at it`() {
        assertFalse(p.onCounted(1, true, 1_000))
        assertFalse(p.onCounted(29, false, 90_000))
        assertTrue(p.onCounted(30, false, 93_000))
    }

    @Test
    fun `no second offer while one is showing`() {
        assertTrue(p.onCounted(30, true, 100_000))
        p.onOfferShown(100_000)
        assertFalse(p.onCounted(31, false, 103_000))
    }

    @Test
    fun `keep scrolling offers again thirty items later`() {
        assertTrue(p.onCounted(30, true, 100_000))
        p.onOfferShown(100_000)
        p.onAnswered(OfferResponse.KEEP, sessionCount = 30)
        assertFalse(p.onCounted(59, false, 400_000))
        assertTrue(p.onCounted(60, false, 403_000))
    }

    @Test
    fun `never two offers inside the minimum gap`() {
        assertTrue(p.onCounted(30, true, 100_000))
        p.onOfferShown(100_000)
        p.onAnswered(OfferResponse.TIMEOUT, sessionCount = 30)
        // Very fast scrolling reaches the next threshold within two minutes: held back, offered later.
        assertFalse(p.onCounted(60, false, 160_000))
        assertTrue(p.onCounted(61, false, 221_000))
    }

    @Test
    fun `take a break restarts from the first threshold in the next session`() {
        assertTrue(p.onCounted(30, true, 100_000))
        p.onOfferShown(100_000)
        p.onAnswered(OfferResponse.BREAK, sessionCount = 30)
        assertFalse(p.onCounted(1, newSession = true, nowMs = 500_000))
        assertFalse(p.onCounted(29, false, 560_000))
        assertTrue(p.onCounted(30, false, 563_000))
    }

    @Test
    fun `a new session resets the threshold after keep scrolling`() {
        p.onOfferShown(100_000)
        p.onAnswered(OfferResponse.KEEP, sessionCount = 30) // next at 60
        assertFalse(p.onCounted(1, newSession = true, nowMs = 900_000))
        assertTrue(p.onCounted(30, false, 990_000))
    }

    @Test
    fun `answering clears the active flag for every response`() {
        for (r in OfferResponse.values()) {
            val q = InterventionPolicy()
            q.onOfferShown(1_000)
            assertTrue(q.offerActive)
            q.onAnswered(r, 30)
            assertFalse(q.offerActive)
        }
    }

    @Test
    fun `reset forgets everything`() {
        p.onOfferShown(100_000)
        p.onAnswered(OfferResponse.KEEP, 30)
        p.reset()
        assertTrue(p.onCounted(30, true, 100_500))
    }

    @Test
    fun `wire names are stable`() {
        assertEquals(listOf("break", "keep", "timeout", "left"), OfferResponse.values().map { it.wire })
    }
}

class ScrollEventLogTest {
    private fun e(ts: Long, r: String = "keep") = ScrollEvent(ts, "2026-11-26", 330, "com.instagram.android", 30, 30, r)

    @Test
    fun `consume removes only what was handed over`() {
        val log = ScrollEventLog()
        log.add(e(1)); log.add(e(2))
        val handed = log.pending()
        log.add(e(3))
        log.consume(handed)
        assertEquals(listOf(3L), log.pending().map { it.ts })
    }

    @Test
    fun `ring buffer drops the oldest beyond the limit`() {
        val log = ScrollEventLog(max = 3)
        for (i in 1L..5L) log.add(e(i))
        assertEquals(listOf(3L, 4L, 5L), log.pending().map { it.ts })
    }

    @Test
    fun `json round trip and damaged input`() {
        val log = ScrollEventLog()
        log.add(e(10, "break"))
        val back = ScrollEventLog.fromJson(log.toJson()).pending().single()
        assertEquals(10L, back.ts)
        assertEquals("break", back.response)
        assertEquals(330, back.tzOffsetMinutes)
        assertTrue(ScrollEventLog.fromJson(null).isEmpty())
        assertTrue(ScrollEventLog.fromJson("{oops").isEmpty())
    }

    @Test
    fun `map matches the channel contract`() {
        assertEquals(
            setOf("ts", "day", "tzOffsetMinutes", "pkg", "sessionCount", "threshold", "response"),
            e(1).toMap().keys,
        )
    }
}
