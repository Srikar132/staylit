package com.staylit.app.services.scroll

import org.json.JSONArray
import org.json.JSONObject

/**
 * One answer to a break offer. Package id, numbers, an enum and a timestamp only: nothing from the screen.
 * Pure (no Android types) so it is JVM testable.
 */
data class ScrollEvent(
    /** Wall clock, epoch ms. Unique per offer, so it doubles as the Firestore document id. */
    val ts: Long,
    val day: String,
    val tzOffsetMinutes: Int,
    val pkg: String,
    val sessionCount: Int,
    val threshold: Int,
    /** [OfferResponse.wire] */
    val response: String,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "ts" to ts,
        "day" to day,
        "tzOffsetMinutes" to tzOffsetMinutes,
        "pkg" to pkg,
        "sessionCount" to sessionCount,
        "threshold" to threshold,
        "response" to response,
    )
}

/** Answers not yet handed to Flutter: a ring buffer so it can never grow without bound. */
class ScrollEventLog(private val max: Int = 200) {

    private val events = ArrayList<ScrollEvent>()

    fun add(event: ScrollEvent) {
        events.add(event)
        while (events.size > max) events.removeAt(0)
    }

    fun pending(): List<ScrollEvent> = events.toList()

    /** Removes what Flutter has stored; events added meanwhile stay. */
    fun consume(done: List<ScrollEvent>) {
        val keys = done.map { it.ts to it.pkg }.toSet()
        events.removeAll { (it.ts to it.pkg) in keys }
    }

    fun clear() = events.clear()

    fun isEmpty(): Boolean = events.isEmpty()

    fun toJson(): String {
        val arr = JSONArray()
        for (e in events) {
            arr.put(
                JSONObject()
                    .put("ts", e.ts)
                    .put("day", e.day)
                    .put("tz", e.tzOffsetMinutes)
                    .put("pkg", e.pkg)
                    .put("n", e.sessionCount)
                    .put("t", e.threshold)
                    .put("r", e.response),
            )
        }
        return arr.toString()
    }

    companion object {
        /** Tolerant: null or damaged text gives an empty log. */
        fun fromJson(json: String?, max: Int = 200): ScrollEventLog {
            val log = ScrollEventLog(max)
            if (json.isNullOrEmpty()) return log
            try {
                val arr = JSONArray(json)
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    log.add(
                        ScrollEvent(
                            ts = o.getLong("ts"),
                            day = o.optString("day", ""),
                            tzOffsetMinutes = o.optInt("tz", 0),
                            pkg = o.optString("pkg", ""),
                            sessionCount = o.optInt("n", 0),
                            threshold = o.optInt("t", 0),
                            response = o.optString("r", ""),
                        ),
                    )
                }
            } catch (e: Exception) {
                return ScrollEventLog(max)
            }
            return log
        }
    }
}
