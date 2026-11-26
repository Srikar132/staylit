package com.staylit.app.services.limits

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LimitsCodecTest {
    @Test
    fun `round trip keeps every package and its limit`() {
        val limits = mapOf("com.instagram.android" to 1_800_000L, "com.google.android.youtube" to 3_600_000L)
        assertEquals(limits, LimitsCodec.decode(LimitsCodec.encode(limits)))
    }

    @Test
    fun `empty and null decode to no limits`() {
        assertTrue(LimitsCodec.decode(null).isEmpty())
        assertTrue(LimitsCodec.decode("").isEmpty())
        assertTrue(LimitsCodec.decode("   \n ").isEmpty())
        assertEquals("", LimitsCodec.encode(emptyMap()))
    }

    @Test
    fun `malformed and non positive lines are skipped, good ones survive`() {
        val raw = listOf(
            "com.a\t60000",
            "garbage",
            "com.b\tnot-a-number",
            "com.c\t0",
            "com.d\t-5",
            "\t100",
            "com.e\t120000\textra",
            "com.f\t90000",
        ).joinToString("\n")
        assertEquals(mapOf("com.a" to 60_000L, "com.f" to 90_000L), LimitsCodec.decode(raw))
    }

    @Test
    fun `encode drops non positive limits`() {
        assertEquals("com.a\t1000", LimitsCodec.encode(mapOf("com.a" to 1000L, "com.b" to 0L, "com.c" to -1L)))
    }
}
