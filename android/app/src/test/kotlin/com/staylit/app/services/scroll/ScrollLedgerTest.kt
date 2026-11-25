package com.staylit.app.services.scroll

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.TimeZone

class ScrollLedgerTest {

    private val ig = "com.instagram.android"
    private val yt = "com.google.android.youtube"

    @Test
    fun `add groups by day and app`() {
        val l = ScrollLedger()
        l.add("2026-11-25", 330, ig, newSession = true)
        l.add("2026-11-25", 330, ig, newSession = false)
        l.add("2026-11-25", 330, yt, newSession = true)
        l.add("2026-11-26", 330, ig, newSession = true)

        val p = l.pending()
        assertEquals(listOf("2026-11-25", "2026-11-26"), p.map { it.day })
        assertEquals(3, p[0].total)
        assertEquals(mapOf(ig to 2, yt to 1), p[0].perApp)
        assertEquals(2, p[0].sessions)
        assertEquals(1, p[1].total)
    }

    @Test
    fun `consume subtracts only what was handed over`() {
        val l = ScrollLedger()
        repeat(5) { l.add("d", 0, ig, newSession = it == 0) }
        val handedOver = l.pending()
        // New counts arrive while Flutter is writing.
        l.add("d", 0, ig, newSession = false)
        l.add("d", 0, yt, newSession = true)

        l.consume(handedOver)

        val left = l.pending().single()
        assertEquals(2, left.total)
        assertEquals(mapOf(ig to 1, yt to 1), left.perApp)
        assertEquals(1, left.sessions)
    }

    @Test
    fun `consume everything empties the ledger`() {
        val l = ScrollLedger()
        l.add("d", 0, ig, true)
        l.consume(l.pending())
        assertTrue(l.isEmpty())
        assertTrue(l.pending().isEmpty())
    }

    @Test
    fun `consume never goes negative and ignores unknown days`() {
        val l = ScrollLedger()
        l.add("d", 0, ig, true)
        l.consume(listOf(DayDelta("d", 0, 9, mapOf(ig to 9, yt to 3), 4), DayDelta("other", 0, 1, emptyMap(), 0)))
        assertTrue(l.isEmpty())
    }

    @Test
    fun `json round trip keeps pending`() {
        val l = ScrollLedger()
        l.add("2026-11-25", -300, ig, true)
        l.add("2026-11-25", -300, yt, false)

        val back = ScrollLedger.fromJson(l.toJson()).pending().single()
        assertEquals(2, back.total)
        assertEquals(mapOf(ig to 1, yt to 1), back.perApp)
        assertEquals(1, back.sessions)
        assertEquals(-300, back.tzOffsetMinutes)
    }

    @Test
    fun `damaged or missing json gives an empty ledger`() {
        assertTrue(ScrollLedger.fromJson(null).isEmpty())
        assertTrue(ScrollLedger.fromJson("").isEmpty())
        assertTrue(ScrollLedger.fromJson("{not json").isEmpty())
    }

    @Test
    fun `day key and offset use the given zone`() {
        val zone = TimeZone.getTimeZone("Asia/Kolkata") // UTC+5:30, no DST
        // 2026-11-25 20:00 UTC = 2026-11-26 01:30 in Kolkata.
        val ms = 1_795_636_800_000L
        assertEquals("2026-11-26", ScrollDayKey.of(ms, zone))
        assertEquals("2026-11-25", ScrollDayKey.of(ms, TimeZone.getTimeZone("UTC")))
        assertEquals(330, ScrollDayKey.offsetMinutes(ms, zone))
    }

    @Test
    fun `toMap matches the channel contract`() {
        val m = DayDelta("d", 330, 3, mapOf("a" to 3), 1).toMap()
        assertEquals(setOf("day", "tzOffsetMinutes", "total", "perApp", "sessions"), m.keys)
    }
}
