package com.staylit.app.services.scroll

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Pure (no Android types) bookkeeping for Scroll damage: counts only, never screen content.
 * Kept framework-free so it can be unit tested on the JVM.
 */

/** Counts for one local day. Used both for pending (unsynced) deltas and for the Flutter bridge. */
data class DayDelta(
    /** Local day key, `yyyy-MM-dd` (same as Dart `DailyStat.dayKey`). */
    val day: String,
    /** Offset of the device time zone from UTC, in minutes, when the count happened. */
    val tzOffsetMinutes: Int,
    val total: Int,
    /** Items per package id (only the allow-listed short-form apps). */
    val perApp: Map<String, Int>,
    val sessions: Int,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "day" to day,
        "tzOffsetMinutes" to tzOffsetMinutes,
        "total" to total,
        "perApp" to perApp,
        "sessions" to sessions,
    )
}

object ScrollDayKey {
    /** `yyyy-MM-dd` for [wallMs] in [zone]. Calendar based, so no java.time (minSdk safe). */
    fun of(wallMs: Long, zone: TimeZone = TimeZone.getDefault()): String {
        val cal = Calendar.getInstance(zone)
        cal.timeInMillis = wallMs
        return "%04d-%02d-%02d".format(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
        )
    }

    /** Same value as Dart `DateTime.timeZoneOffset.inMinutes` at that moment. */
    fun offsetMinutes(wallMs: Long, zone: TimeZone = TimeZone.getDefault()): Int =
        zone.getOffset(wallMs) / 60_000
}

/** Counts not yet handed to Flutter, keyed by day. Survives restarts through [toJson]/[fromJson]. */
class ScrollLedger {

    private class Day(var tz: Int) {
        var total = 0
        var sessions = 0
        val perApp = LinkedHashMap<String, Int>()
        fun isEmpty() = total <= 0 && sessions <= 0
    }

    private val days = LinkedHashMap<String, Day>()

    fun add(day: String, tzOffsetMinutes: Int, pkg: String, newSession: Boolean) {
        val d = days.getOrPut(day) { Day(tzOffsetMinutes) }
        d.tz = tzOffsetMinutes
        d.total += 1
        d.perApp[pkg] = (d.perApp[pkg] ?: 0) + 1
        if (newSession) d.sessions += 1
    }

    fun isEmpty(): Boolean = days.values.all { it.isEmpty() }

    /** Days with something to send, oldest first. */
    fun pending(): List<DayDelta> = days.entries
        .filter { !it.value.isEmpty() }
        .sortedBy { it.key }
        .map { (key, d) ->
            DayDelta(key, d.tz, d.total, d.perApp.filterValues { it > 0 }.toMap(), d.sessions)
        }

    /**
     * Subtracts what Flutter has stored. Counts that arrived after [pending] was read stay.
     * Never goes below zero; emptied days are dropped.
     */
    fun consume(done: List<DayDelta>) {
        for (delta in done) {
            val d = days[delta.day] ?: continue
            d.total = (d.total - delta.total).coerceAtLeast(0)
            d.sessions = (d.sessions - delta.sessions).coerceAtLeast(0)
            for ((pkg, n) in delta.perApp) {
                val left = ((d.perApp[pkg] ?: 0) - n).coerceAtLeast(0)
                if (left == 0) d.perApp.remove(pkg) else d.perApp[pkg] = left
            }
            if (d.isEmpty()) days.remove(delta.day)
        }
    }

    fun clear() = days.clear()

    fun toJson(): String {
        val arr = JSONArray()
        for (delta in pending()) {
            arr.put(
                JSONObject()
                    .put("day", delta.day)
                    .put("tz", delta.tzOffsetMinutes)
                    .put("total", delta.total)
                    .put("sessions", delta.sessions)
                    .put("perApp", JSONObject(delta.perApp)),
            )
        }
        return arr.toString()
    }

    companion object {
        /** Tolerant: a null or damaged string gives an empty ledger. */
        fun fromJson(json: String?): ScrollLedger {
            val ledger = ScrollLedger()
            if (json.isNullOrEmpty()) return ledger
            try {
                val arr = JSONArray(json)
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val day = Day(o.optInt("tz", 0))
                    day.total = o.optInt("total", 0)
                    day.sessions = o.optInt("sessions", 0)
                    o.optJSONObject("perApp")?.let { per ->
                        for (key in per.keys()) day.perApp[key] = per.optInt(key, 0)
                    }
                    if (!day.isEmpty()) ledger.days[o.getString("day")] = day
                }
            } catch (e: Exception) {
                return ScrollLedger()
            }
            return ledger
        }
    }
}
