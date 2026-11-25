package com.staylit.app.services.focus

/**
 * Pure (no Android types) helpers that stop the focus enforcement from flickering. The accessibility window
 * list is noisy while windows open, close, resize or get a cover attached: a window can be missing from one
 * snapshot, or look the wrong size for a few frames. Reacting to every snapshot makes covers blink on and off
 * and sends Home at the wrong moment. JVM tested.
 */

/**
 * Keeps an item "present" for [graceMs] after it last appeared, so a snapshot that misses it for a moment
 * does not remove it (and its cover). Items that stay gone longer than [graceMs] are dropped.
 */
class MissingGrace<K, V>(private val graceMs: Long) {
    private val lastSeen = HashMap<K, Long>()
    private val lastValue = HashMap<K, V>()

    /** [current] = what the latest snapshot shows. Returns it plus anything missing for less than the grace time. */
    fun update(nowMs: Long, current: Map<K, V>): Map<K, V> {
        for ((k, v) in current) {
            lastSeen[k] = nowMs
            lastValue[k] = v
        }
        val result = LinkedHashMap<K, V>(current)
        val it = lastSeen.entries.iterator()
        while (it.hasNext()) {
            val (k, seen) = it.next()
            if (current.containsKey(k)) continue
            if (nowMs - seen <= graceMs) {
                result[k] = lastValue.getValue(k)
            } else {
                it.remove()
                lastValue.remove(k)
            }
        }
        return result
    }

    fun reset() {
        lastSeen.clear()
        lastValue.clear()
    }
}

/** A condition only counts as true after it has been continuously true for [minStableMs]. */
class StableFlag(private val minStableMs: Long) {
    private var since: Long? = null

    fun update(nowMs: Long, value: Boolean): Boolean {
        if (!value) {
            since = null
            return false
        }
        val start = since ?: nowMs.also { since = it }
        return nowMs - start >= minStableMs
    }

    fun reset() {
        since = null
    }
}

/**
 * When may a cover be removed because its window is missing from the window list?
 *
 * Seen on a device (Android 15): attaching an accessibility overlay to a picture-in-picture window makes that
 * window disappear from AccessibilityService.windows for as long as the overlay exists. Removing the cover
 * because "the window is gone" therefore removes the very thing that hid it, the window comes back, the
 * cover is attached again, and so on (the on / off flicker). A window-attached cover is tied to its window
 * by the system and disappears with it, so absence alone is no reason to remove it.
 */
object CoverRetention {

    /** How long an attached cover is kept after its window was last seen, before its resources are released. */
    const val ATTACHED_KEEP_MS = 15_000L

    fun shouldKeep(attached: Boolean, lastSeenMs: Long, nowMs: Long): Boolean =
        attached && nowMs - lastSeenMs < ATTACHED_KEEP_MS
}
