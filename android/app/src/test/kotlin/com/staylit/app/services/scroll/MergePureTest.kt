package com.staylit.app.services.scroll

import com.staylit.app.services.scroll.IslandPolicy.Action
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PassLedgerTest {
    private val ig = "com.instagram.android"
    private val yt = "com.google.android.youtube"
    private val t0 = 1_000_000_000_000L

    @Test
    fun `a pass is active until its end and then gone`() {
        val l = PassLedger()
        assertTrue(l.start(ig, 10, t0))
        assertTrue(l.isActive(ig, t0 + 9 * 60_000))
        assertEquals(60_000L, l.remainingMs(ig, t0 + 9 * 60_000))
        assertFalse(l.isActive(ig, t0 + 10 * 60_000))
        assertEquals(0L, l.remainingMs(ig, t0 + 10 * 60_000))
    }

    @Test
    fun `only five, ten and twenty minutes are allowed`() {
        val l = PassLedger()
        for (bad in listOf(0, 1, 7, 15, 60, -5)) assertFalse(l.start(ig, bad, t0))
        for (ok in listOf(5, 10, 20)) assertTrue(l.start(ig, ok, t0))
        assertFalse(l.isActive("com.other", t0))
    }

    @Test
    fun `a pass is per app`() {
        val l = PassLedger()
        l.start(ig, 5, t0)
        assertTrue(l.isActive(ig, t0 + 1_000))
        assertFalse(l.isActive(yt, t0 + 1_000))
    }

    @Test
    fun `a clock moved back cannot stretch a pass`() {
        val l = PassLedger()
        l.start(ig, 5, t0)
        // Clock jumps back two hours: the stored end is now far in the future, so the pass is void.
        assertFalse(l.isActive(ig, t0 - 2 * 3_600_000L))
    }

    @Test
    fun `a clock moved forward just ends it early`() {
        val l = PassLedger()
        l.start(ig, 20, t0)
        assertFalse(l.isActive(ig, t0 + 3_600_000L))
    }

    @Test
    fun `restarting a pass replaces the old end`() {
        val l = PassLedger()
        l.start(ig, 5, t0)
        l.start(ig, 20, t0 + 60_000)
        assertEquals(20 * 60_000L, l.remainingMs(ig, t0 + 60_000))
    }

    @Test
    fun `active packages soonest first, cancel and cancel all`() {
        val l = PassLedger()
        l.start(ig, 20, t0)
        l.start(yt, 5, t0)
        assertEquals(listOf(yt, ig), l.activePackages(t0 + 1))
        l.cancel(yt)
        assertEquals(listOf(ig), l.activePackages(t0 + 1))
        l.cancelAll()
        assertTrue(l.activePackages(t0 + 1).isEmpty())
    }

    @Test
    fun `json round trip and damaged input`() {
        val l = PassLedger()
        l.start(ig, 10, t0)
        val back = PassLedger.fromJson(l.toJson())
        assertTrue(back.isActive(ig, t0 + 1_000))
        assertFalse(PassLedger.fromJson(null).isActive(ig, t0))
        assertFalse(PassLedger.fromJson("{oops").isActive(ig, t0))
    }
}

class LitSheetSpecTest {
    @Test
    fun `offer is a non modal card with take a break and keep scrolling`() {
        val s = LitSheetSpec.offer(30, "Reels")
        assertEquals(SheetMode.OFFER, s.mode)
        assertFalse(s.modal)
        assertEquals("You have scrolled 30 in a row", s.title)
        assertEquals("Take a break", s.primaryLabel)
        assertEquals("Keep scrolling", s.secondaryLabel)
        assertTrue(s.passMinutes.isEmpty())
    }

    @Test
    fun `blocked offers 5 10 20 passes when nothing forbids them`() {
        val s = LitSheetSpec.blocked("Reels", focusActive = false, parentalLocked = false)
        assertTrue(s.modal)
        assertEquals("Reels is blocked", s.title)
        assertEquals("Go back", s.primaryLabel)
        assertEquals(listOf(5, 10, 20), s.passMinutes)
        assertNull(s.hint)
    }

    @Test
    fun `no passes under a parental PIN, with a hint`() {
        val s = LitSheetSpec.blocked("Shorts", focusActive = false, parentalLocked = true)
        assertTrue(s.passMinutes.isEmpty())
        assertEquals("Ask for the PIN in Blocks to take a break", s.hint)
    }

    @Test
    fun `no passes during a focus session and focus wins over the PIN hint`() {
        val s = LitSheetSpec.blocked("Reels", focusActive = true, parentalLocked = true)
        assertTrue(s.passMinutes.isEmpty())
        assertEquals("Focus session in progress", s.hint)
    }

    @Test
    fun `times up names the minutes and follows the same rules`() {
        val s = LitSheetSpec.timesUp("Reels", 10, focusActive = false, parentalLocked = false)
        assertEquals("Time's up", s.title)
        assertEquals("You watched Reels for 10 min.", s.body)
        assertEquals("Done", s.primaryLabel)
        assertEquals(listOf(5, 10, 20), s.passMinutes)
        assertTrue(LitSheetSpec.timesUp("Reels", 10, true, false).passMinutes.isEmpty())
    }

    @Test
    fun `the four apps map to the Dart toggle keys`() {
        val keys = listOf(
            "com.instagram.android", "com.google.android.youtube",
            "com.zhiliaoapp.musically", "com.facebook.katana",
        ).map { ShortFormApps.forPackage(it)!! }.map { "${it.platform}_${it.feature}" }
        assertEquals(listOf("Instagram_Reels", "YouTube_Shorts", "TikTok_Videos", "Facebook_Reels"), keys)
        assertNull(ShortFormApps.forPackage("com.other"))
    }
}

class IslandCardSpecTest {
    @Test
    fun `mood labels match the Dart ScrollMood`() {
        assertEquals("Calm", IslandCardSpec.moodLabel(1))
        assertEquals("Warming up", IslandCardSpec.moodLabel(2))
        assertEquals("Getting hooked", IslandCardSpec.moodLabel(3))
        assertEquals("Doomscrolling", IslandCardSpec.moodLabel(4))
        assertEquals("Meltdown", IslandCardSpec.moodLabel(5))
        assertEquals("Calm", IslandCardSpec.moodLabel(-3))
        assertEquals("Meltdown", IslandCardSpec.moodLabel(99))
    }

    @Test
    fun `minutes are formatted for a glance`() {
        assertEquals("0 min", IslandCardSpec.formatMinutes(0))
        assertEquals("0 min", IslandCardSpec.formatMinutes(-4))
        assertEquals("14 min", IslandCardSpec.formatMinutes(14))
        assertEquals("1 h 00", IslandCardSpec.formatMinutes(60))
        assertEquals("1 h 05", IslandCardSpec.formatMinutes(65))
        assertEquals("2 h 30", IslandCardSpec.formatMinutes(150))
    }

    @Test
    fun `countdown rounds up and never shows zero while time is left`() {
        assertEquals("4:12", IslandCardSpec.formatCountdown(252_000))
        assertEquals("0:01", IslandCardSpec.formatCountdown(1))
        assertEquals("0:00", IslandCardSpec.formatCountdown(0))
        assertEquals("0:00", IslandCardSpec.formatCountdown(-500))
        assertEquals("20:00", IslandCardSpec.formatCountdown(20 * 60_000L))
        assertEquals("4:59", IslandCardSpec.formatCountdown(298_500))
    }

    @Test
    fun `main button switches during a pass`() {
        val idle = IslandCardState(30, 100, 12, 2, null)
        val pass = idle.copy(passRemainingMs = 60_000)
        assertEquals(IslandCardAction.TAKE_BREAK, IslandCardSpec.primaryAction(idle))
        assertEquals("Take a break", IslandCardSpec.primaryLabel(idle))
        assertEquals(IslandCardAction.END_BREAK, IslandCardSpec.primaryAction(pass))
        assertEquals("End break early", IslandCardSpec.primaryLabel(pass))
    }

    @Test
    fun `session minutes never go negative`() {
        assertEquals(0, IslandCardSpec.sessionMinutes(10_000, 5_000))
        assertEquals(2, IslandCardSpec.sessionMinutes(0, 150_000))
    }
}

class IslandPolicyPassTest {
    @Test
    fun `during a pass the pill shows from the first item`() {
        val p = IslandPolicy()
        assertEquals(Action.SHOW, p.onCounted(1, newSession = true, nowMs = 1_000, alwaysShow = true))
        assertEquals(Action.UPDATE, p.onCounted(2, false, 2_000, alwaysShow = true))
    }

    @Test
    fun `a new session during a pass keeps the pill`() {
        val p = IslandPolicy()
        p.onCounted(1, true, 1_000, alwaysShow = true)
        assertEquals(Action.SHOW, p.onCounted(1, newSession = true, nowMs = 90_000, alwaysShow = true))
        assertTrue(p.visible)
    }
}

class ScrollEventKindTest {
    @Test
    fun `kind and minutes survive json and default for old rows`() {
        val log = ScrollEventLog()
        log.add(ScrollEvent(1, "d", 0, "p", 0, 0, "start", kind = "pass", minutes = 10))
        val back = ScrollEventLog.fromJson(log.toJson()).pending().single()
        assertEquals("pass", back.kind)
        assertEquals(10, back.minutes)

        val old = """[{"ts":5,"day":"d","tz":0,"pkg":"p","n":30,"t":30,"r":"keep"}]"""
        val oldRow = ScrollEventLog.fromJson(old).pending().single()
        assertEquals("offer", oldRow.kind)
        assertEquals(0, oldRow.minutes)
    }

    @Test
    fun `map carries kind and minutes`() {
        val m = ScrollEvent(1, "d", 0, "p", 0, 0, "start", "pass", 5).toMap()
        assertEquals("pass", m["kind"])
        assertEquals(5, m["minutes"])
    }
}
