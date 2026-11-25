package com.staylit.app.services.focus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionDueTest {
    @Test
    fun `a timer session is due once its planned time has passed`() {
        assertFalse(SessionDue.isDue("timer", 25, 24 * 60_000L + 59_000L, paused = false))
        assertTrue(SessionDue.isDue("timer", 25, 25 * 60_000L, paused = false))
        assertTrue(SessionDue.isDue("Timer", 1, 10 * 60_000L, paused = false))
    }

    @Test
    fun `paused, stopwatch, pomodoro and empty plans are never due`() {
        assertFalse(SessionDue.isDue("timer", 25, 99 * 60_000L, paused = true))
        assertFalse(SessionDue.isDue("stopwatch", 25, 99 * 60_000L, paused = false))
        assertFalse(SessionDue.isDue("pomodoro", 25, 99 * 60_000L, paused = false))
        assertFalse(SessionDue.isDue("timer", 0, 99 * 60_000L, paused = false))
        assertFalse(SessionDue.isDue("timer", -3, 99 * 60_000L, paused = false))
    }
}

class EjectPolicyTest {
    private val own = "com.staylit.app"
    private val w = 1080
    private val h = 2400

    private fun win(pkg: String, l: Int, t: Int, r: Int, b: Int, kind: WindowKind = WindowKind.APPLICATION) =
        WindowSnapshot(1, pkg, kind, WindowBounds(l, t, r, b))

    @Test
    fun `normal case escalates front, home, cover`() {
        assertEquals(EjectStep.BRING_STAYLIT_FRONT, EjectPolicy.stepFor(0, staylitFloating = false))
        assertEquals(EjectStep.GO_HOME, EjectPolicy.stepFor(1, staylitFloating = false))
        assertEquals(EjectStep.COVER_FULL_SCREEN, EjectPolicy.stepFor(2, staylitFloating = false))
        assertEquals(EjectStep.COVER_FULL_SCREEN, EjectPolicy.stepFor(9, staylitFloating = false))
    }

    @Test
    fun `a floating Staylit skips the useless bring to front`() {
        assertEquals(EjectStep.GO_HOME, EjectPolicy.stepFor(0, staylitFloating = true))
        assertEquals(EjectStep.COVER_FULL_SCREEN, EjectPolicy.stepFor(1, staylitFloating = true))
    }

    @Test
    fun `negative attempts behave like the first`() {
        assertEquals(EjectStep.BRING_STAYLIT_FRONT, EjectPolicy.stepFor(-4, staylitFloating = false))
    }

    @Test
    fun `floating means one of our windows that does not fill the screen`() {
        val floating = win(own, 100, 300, 900, 1500)
        val fullStaylit = win(own, 0, 0, w, h)
        val blocked = win("com.google.android.youtube", 0, 0, w, h)
        assertTrue(EjectPolicy.isStaylitFloating(listOf(blocked, floating), own, w, h))
        assertFalse(EjectPolicy.isStaylitFloating(listOf(blocked, fullStaylit), own, w, h))
        assertFalse(EjectPolicy.isStaylitFloating(listOf(blocked), own, w, h))
    }

    @Test
    fun `only application windows count, not the pip or other windows`() {
        val pip = win(own, 600, 100, 1000, 400, kind = WindowKind.PIP)
        assertFalse(EjectPolicy.isStaylitFloating(listOf(pip), own, w, h))
    }
}
