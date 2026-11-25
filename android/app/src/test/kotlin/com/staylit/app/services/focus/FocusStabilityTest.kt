package com.staylit.app.services.focus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MissingGraceTest {
    private val g = MissingGrace<Int, String>(600)

    @Test
    fun `an item missing for a moment is kept`() {
        assertEquals(mapOf(7 to "a"), g.update(0, mapOf(7 to "a")))
        // Dropped from the next snapshot 60 ms later (the cover-attach blink): still there.
        assertEquals(mapOf(7 to "a"), g.update(60, emptyMap()))
        // Back again 120 ms after that: no gap was ever visible.
        assertEquals(mapOf(7 to "a"), g.update(180, mapOf(7 to "a")))
    }

    @Test
    fun `an item missing longer than the grace time is dropped`() {
        g.update(0, mapOf(1 to "x"))
        assertEquals(mapOf(1 to "x"), g.update(600, emptyMap()))
        assertTrue(g.update(601, emptyMap()).isEmpty())
        assertTrue(g.update(700, emptyMap()).isEmpty())
    }

    @Test
    fun `the latest value is the one kept`() {
        g.update(0, mapOf(1 to "old"))
        g.update(100, mapOf(1 to "new"))
        assertEquals("new", g.update(200, emptyMap())[1])
    }

    @Test
    fun `items are tracked independently`() {
        g.update(0, mapOf(1 to "a", 2 to "b"))
        val r = g.update(300, mapOf(2 to "b"))
        assertEquals(setOf(1, 2), r.keys)
        val later = g.update(700, mapOf(2 to "b"))
        assertEquals(setOf(2), later.keys)
    }

    @Test
    fun `reset forgets everything`() {
        g.update(0, mapOf(1 to "a"))
        g.reset()
        assertTrue(g.update(10, emptyMap()).isEmpty())
    }

    @Test
    fun `the on off loop from the device log never shows a gap`() {
        // Attach at t, window missing 60 ms later, back 120 ms after that, repeated every 180 ms.
        var t = 0L
        repeat(20) {
            assertTrue(g.update(t, mapOf(5 to "pip")).containsKey(5))
            assertTrue(g.update(t + 60, emptyMap()).containsKey(5))
            t += 180
        }
    }
}

class StableFlagTest {
    @Test
    fun `becomes true only after being true long enough`() {
        val f = StableFlag(1200)
        assertFalse(f.update(0, true))
        assertFalse(f.update(1000, true))
        assertTrue(f.update(1200, true))
        assertTrue(f.update(5000, true))
    }

    @Test
    fun `a single false starts it over`() {
        val f = StableFlag(1200)
        f.update(0, true)
        assertFalse(f.update(900, false))
        assertFalse(f.update(1000, true))
        assertFalse(f.update(2000, true))
        assertTrue(f.update(2200, true))
    }

    @Test
    fun `a window that is only opening never counts as floating`() {
        val f = StableFlag(1200)
        // Staylit launching: partial bounds for about 400 ms, then full screen.
        assertFalse(f.update(0, true))
        assertFalse(f.update(200, true))
        assertFalse(f.update(400, false))
        assertFalse(f.update(600, false))
    }

    @Test
    fun `reset clears it`() {
        val f = StableFlag(100)
        f.update(0, true)
        f.reset()
        assertFalse(f.update(200, true))
    }
}

class CompactHysteresisTest {
    private val density = 2.75f

    private fun px(dp: Float) = (dp * density).toInt()

    @Test
    fun `a new cover uses the plain threshold`() {
        assertTrue(CoverLayoutPolicy.isCompactSticky(null, px(200f), px(900f), density))
        assertFalse(CoverLayoutPolicy.isCompactSticky(null, px(300f), px(900f), density))
    }

    @Test
    fun `a window hovering around the threshold does not flip back and forth`() {
        // Width wobbling 250..270 dp while opening: compact once, stays compact.
        var compact: Boolean? = null
        val flips = mutableListOf<Boolean>()
        for (w in listOf(255f, 262f, 258f, 268f, 259f, 264f, 256f)) {
            val next = CoverLayoutPolicy.isCompactSticky(compact, px(w), px(900f), density)
            if (next != compact) flips.add(next)
            compact = next
        }
        assertEquals(1, flips.size)
    }

    @Test
    fun `leaves compact only when clearly bigger, and enters only when clearly smaller`() {
        assertTrue(CoverLayoutPolicy.isCompactSticky(true, px(280f), px(900f), density)) // 280 < 312
        assertFalse(CoverLayoutPolicy.isCompactSticky(true, px(320f), px(900f), density))
        assertFalse(CoverLayoutPolicy.isCompactSticky(false, px(240f), px(900f), density)) // 240 > 221
        assertTrue(CoverLayoutPolicy.isCompactSticky(false, px(200f), px(900f), density))
    }

    @Test
    fun `bad density is never compact`() {
        assertFalse(CoverLayoutPolicy.isCompactSticky(null, 100, 100, 0f))
    }
}
