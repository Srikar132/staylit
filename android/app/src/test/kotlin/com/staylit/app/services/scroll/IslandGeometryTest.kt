package com.staylit.app.services.scroll

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class IslandGeometryTest {

    // A 1080 x 2400 phone at density 3 (dp(x) = 3x).
    private val w = 1080
    private val h = 2400
    private val density = 3f
    private val statusBar = 100

    private fun layout(vararg cutouts: PxRect) =
        IslandGeometry.compute(w, h, density, cutouts.toList(), statusBar)

    @Test
    fun `centred camera hole is wrapped by the pill`() {
        val l = layout(PxRect(520, 0, 560, 80))!!
        assertTrue(l.wrapsCutout)
        assertEquals(40, l.cutoutWidthPx)
        // 40 + 2 side segments of 52dp (156 px)
        assertEquals(40 + 2 * 156, l.widthPx)
        // cutout bottom 80 + 2dp(6) = 86, min height 28dp = 84
        assertEquals(86, l.heightPx)
        assertEquals(0, l.xOffsetPx)
        assertEquals(0, l.yPx)
    }

    @Test
    fun `slightly off-centre hole still wraps and the pill follows it`() {
        val l = layout(PxRect(600, 0, 640, 90))!!
        assertTrue(l.wrapsCutout)
        assertEquals(80, l.xOffsetPx) // centre 620 vs screen centre 540
        assertEquals(0, l.yPx)
    }

    @Test
    fun `a notch that is wide but not huge is wrapped`() {
        val l = layout(PxRect(330, 0, 750, 110))!! // 420 px = 39% of the screen
        assertTrue(l.wrapsCutout)
        assertEquals(420, l.cutoutWidthPx)
        assertEquals(116, l.heightPx)
    }

    @Test
    fun `a huge cutout is not wrapped, the pill sits below it`() {
        val l = layout(PxRect(200, 0, 880, 140))!! // 63% of the screen
        assertFalse(l.wrapsCutout)
        assertEquals(140 + 12, l.yPx) // below the cutout + 4dp gap
        assertEquals(0, l.xOffsetPx)
    }

    @Test
    fun `no cutout gives a compact pill under the status bar`() {
        val l = layout()!!
        assertFalse(l.wrapsCutout)
        assertEquals(288, l.widthPx) // 96dp
        assertEquals(84, l.heightPx) // 28dp
        assertEquals(statusBar + 12, l.yPx)
        assertEquals(0, l.xOffsetPx)
    }

    @Test
    fun `corner punch hole does not move the compact pill`() {
        val left = layout(PxRect(60, 0, 100, 80))!!
        val right = layout(PxRect(980, 0, 1020, 80))!!
        assertFalse(left.wrapsCutout)
        assertFalse(right.wrapsCutout)
        assertEquals(statusBar + 12, left.yPx)
        assertEquals(statusBar + 12, right.yPx)
    }

    @Test
    fun `off-centre hole that overlaps the compact pill pushes it down`() {
        // centre 680 is 140 px from the middle: not centred (limit 129), but its left edge is inside the pill.
        val l = layout(PxRect(660, 0, 700, 200))!!
        assertFalse(l.wrapsCutout)
        assertEquals(200 + 12, l.yPx)
    }

    @Test
    fun `double cutout, neither centred, leaves the pill alone`() {
        val l = layout(PxRect(300, 0, 340, 80), PxRect(740, 0, 780, 80))!!
        assertFalse(l.wrapsCutout)
        assertEquals(statusBar + 12, l.yPx)
    }

    @Test
    fun `bottom and side cutouts are ignored`() {
        val l = layout(PxRect(500, 2300, 580, 2400), PxRect(0, 900, 30, 1000))!!
        assertFalse(l.wrapsCutout)
        assertEquals(statusBar + 12, l.yPx)
    }

    @Test
    fun `landscape and bad input hide the pill`() {
        assertNull(IslandGeometry.compute(2400, 1080, density, emptyList(), statusBar))
        assertNull(IslandGeometry.compute(0, 2400, density, emptyList(), statusBar))
        assertNull(IslandGeometry.compute(w, h, 0f, emptyList(), statusBar))
    }

    @Test
    fun `unknown status bar height still gives a valid position`() {
        val l = IslandGeometry.compute(w, h, density, emptyList(), -5)
        assertNotNull(l)
        assertEquals(12, l!!.yPx)
    }

    @Test
    fun `wrapped pill never exceeds 80 percent of the screen`() {
        val l = layout(PxRect(100, 0, 940, 80))
        // 840 px is more than 45% of the screen, so it is not wrapped at all
        assertFalse(l!!.wrapsCutout)
        assertTrue(l.widthPx <= (w * 0.8f).toInt())
    }
}
