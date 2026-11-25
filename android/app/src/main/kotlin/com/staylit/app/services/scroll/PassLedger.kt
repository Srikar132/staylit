package com.staylit.app.services.scroll

import org.json.JSONObject

/**
 * Pure (no Android types) record of "break passes": a timed allowance to watch short-form content in an
 * app that is otherwise blocked. Per package, wall-clock end time so it survives process death.
 */
class PassLedger {

    companion object {
        /** The only lengths a pass can have, in minutes. */
        val ALLOWED_MINUTES = intArrayOf(5, 10, 20)

        /** A stored end further in the future than the longest pass plus this is a moved-back clock: expired. */
        private const val CLOCK_SLACK_MS = 60_000L

        private val MAX_MS = ALLOWED_MINUTES.max() * 60_000L + CLOCK_SLACK_MS

        /** Tolerant: null or damaged text gives an empty ledger. */
        fun fromJson(json: String?): PassLedger {
            val ledger = PassLedger()
            if (json.isNullOrEmpty()) return ledger
            try {
                val o = JSONObject(json)
                for (key in o.keys()) ledger.ends[key] = o.getLong(key)
            } catch (e: Exception) {
                return PassLedger()
            }
            return ledger
        }
    }

    private val ends = LinkedHashMap<String, Long>()

    /** Starts (or restarts) a pass. Returns false if [minutes] is not one of [ALLOWED_MINUTES]. */
    fun start(pkg: String, minutes: Int, nowWallMs: Long): Boolean {
        if (minutes !in ALLOWED_MINUTES) return false
        ends[pkg] = nowWallMs + minutes * 60_000L
        return true
    }

    /** True while the pass has time left. An expired or implausible entry is removed. */
    fun isActive(pkg: String, nowWallMs: Long): Boolean {
        val end = ends[pkg] ?: return false
        val left = end - nowWallMs
        if (left <= 0 || left > MAX_MS) {
            ends.remove(pkg)
            return false
        }
        return true
    }

    fun remainingMs(pkg: String, nowWallMs: Long): Long =
        if (isActive(pkg, nowWallMs)) ends.getValue(pkg) - nowWallMs else 0L

    /** Packages with time left, soonest to end first. */
    fun activePackages(nowWallMs: Long): List<String> =
        ends.keys.toList().filter { isActive(it, nowWallMs) }.sortedBy { ends[it] }

    fun cancel(pkg: String) {
        ends.remove(pkg)
    }

    fun cancelAll() = ends.clear()

    fun toJson(): String {
        val o = JSONObject()
        for ((k, v) in ends) o.put(k, v)
        return o.toString()
    }
}
