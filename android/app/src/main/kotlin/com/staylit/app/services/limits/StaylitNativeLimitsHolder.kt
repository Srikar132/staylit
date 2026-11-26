package com.staylit.app.services.limits

import android.content.Context
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * Pure (no Android types) text format for the persisted limits: one `package<TAB>limitMs` per line.
 * Package ids never contain a tab or newline. Kept separate so it is unit tested on the JVM.
 */
object LimitsCodec {
    fun encode(limits: Map<String, Long>): String =
        limits.entries
            .filter { it.value > 0 }
            .joinToString("\n") { "${it.key}\t${it.value}" }

    /** Malformed or non-positive lines are skipped, never thrown on: a damaged file must not break enforcement. */
    fun decode(raw: String?): Map<String, Long> {
        if (raw.isNullOrBlank()) return emptyMap()
        val out = LinkedHashMap<String, Long>()
        for (line in raw.lineSequence()) {
            val parts = line.split('\t')
            if (parts.size != 2) continue
            val pkg = parts[0].trim()
            val ms = parts[1].trim().toLongOrNull() ?: continue
            if (pkg.isNotEmpty() && ms > 0) out[pkg] = ms
        }
        return out
    }
}

/**
 * Singleton holder for app limits, accessible from both MainActivity and AccessibilityService.
 * Thread-safe storage for daily usage limits per package.
 *
 * The limits are also saved in SharedPreferences, so enforcement survives the process being killed or
 * the phone rebooting (the system restarts the accessibility service on its own) without the user opening
 * Staylit. Flutter (Firestore) stays the source of truth: every push from it replaces what is stored.
 */
object StaylitNativeLimitsHolder {
    private const val TAG = "StaylitNativeLimitsHolder"
    private const val PREFS = "staylit_native_limits"
    private const val KEY_LIMITS = "limits"

    // Package name -> daily limit in milliseconds
    val dailyLimits: ConcurrentHashMap<String, Long> = ConcurrentHashMap()

    @Volatile private var appContext: Context? = null
    @Volatile private var loaded = false

    /**
     * Loads the saved limits once per process. Call from every native entry point that can run before
     * Flutter has pushed anything (the accessibility service, the channel handler). A push from Flutter
     * that already happened wins over the saved copy.
     */
    @Synchronized
    fun init(context: Context) {
        if (appContext == null) appContext = context.applicationContext
        if (loaded) return
        loaded = true
        val saved = LimitsCodec.decode(prefs()?.getString(KEY_LIMITS, null))
        if (saved.isNotEmpty() && dailyLimits.isEmpty()) {
            dailyLimits.putAll(saved)
        }
        Log.i(TAG, "Loaded ${dailyLimits.size} saved app limits: ${dailyLimits.keys}")
    }

    /**
     * Replaces ALL limits with [limitsMap] (not a merge): packages missing from it lose their limit.
     * Flutter always sends the complete set of active limits. Entries with 0 or less minutes are ignored.
     * @param limitsMap Map of package names to limit minutes
     */
    @Synchronized
    fun updateLimits(limitsMap: Map<String, Int>) {
        Log.d(TAG, "🔄 updateLimits called - replacing all limits with ${limitsMap.size} new limits")
        loaded = true // a push from Flutter is newer than anything saved
        dailyLimits.clear()
        limitsMap.forEach { (packageName, limitMinutes) ->
            if (limitMinutes <= 0) return@forEach
            dailyLimits[packageName] = limitMinutes * 60_000L
            Log.d(TAG, "  ✅ Set limit for $packageName: $limitMinutes minutes")
        }
        persist()
        Log.i(TAG, "✅ Updated ${dailyLimits.size} app limits - Current limits: ${dailyLimits.keys}")
    }

    /**
     * Get limit for a specific package
     * @return limit in milliseconds, or null if no limit set
     */
    fun getLimitMs(packageName: String): Long? {
        return dailyLimits[packageName]
    }

    /**
     * Check if package has a limit
     */
    fun hasLimit(packageName: String): Boolean {
        return dailyLimits.containsKey(packageName)
    }

    /**
     * Remove limit for a package
     */
    @Synchronized
    fun removeLimit(packageName: String) {
        dailyLimits.remove(packageName)
        persist()
        Log.d(TAG, "Removed limit for $packageName")
    }

    /**
     * Clear all limits
     */
    @Synchronized
    fun clearAllLimits() {
        dailyLimits.clear()
        persist()
        Log.d(TAG, "Cleared all limits")
    }

    /**
     * Get all packages with limits
     */
    fun getAllPackagesWithLimits(): Set<String> {
        return dailyLimits.keys.toSet()
    }

    private fun prefs() = appContext?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun persist() {
        try {
            prefs()?.edit()?.putString(KEY_LIMITS, LimitsCodec.encode(dailyLimits))?.apply()
        } catch (e: Exception) {
            Log.e(TAG, "Could not save app limits", e)
        }
    }
}
