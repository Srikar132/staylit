package com.staylit.app.services.scroll

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log

/** Lets MainActivity (when its Flutter engine is alive) hear that new counts exist. */
object ScrollDamageNotifier {
    @Volatile
    var listener: ((Map<String, Any>) -> Unit)? = null
}

/**
 * Persistent side of Scroll damage (SharedPreferences `scroll_damage`): the enabled flag, the account the
 * counts belong to, and the ledger of counts Flutter has not stored yet. Counts and day keys only.
 *
 * Own prefs file on purpose: `BlockingConfig.clearAllConfigs()` must not wipe counts.
 */
class ScrollDamageStore private constructor(context: Context) {

    companion object {
        private const val TAG = "ScrollDamage"
        private const val PREFS = "scroll_damage"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_UID = "uid"
        private const val KEY_LEDGER = "ledger"

        /** Batch window for the "new counts" ping to Flutter. */
        private const val PING_DELAY_MS = 5_000L

        @Volatile
        private var INSTANCE: ScrollDamageStore? = null

        fun getInstance(context: Context): ScrollDamageStore =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: ScrollDamageStore(context.applicationContext).also { INSTANCE = it }
            }
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val ledger = ScrollLedger.fromJson(prefs.getString(KEY_LEDGER, null))
    private val pingHandler = Handler(Looper.getMainLooper())
    private var pingScheduled = false

    @Volatile
    private var enabled = prefs.getBoolean(KEY_ENABLED, false)

    fun isEnabled(): Boolean = enabled

    /**
     * Mirrors the Flutter setting. A different [uid] than the stored one drops unsynced counts, so one
     * account's counts are never written to the next account on a shared device.
     */
    @Synchronized
    fun setEnabled(enabled: Boolean, uid: String) {
        val storedUid = prefs.getString(KEY_UID, "") ?: ""
        if (uid.isNotEmpty() && storedUid.isNotEmpty() && uid != storedUid) {
            ledger.clear()
            Log.d(TAG, "account changed, unsynced counts dropped")
        }
        this.enabled = enabled
        val editor = prefs.edit()
        editor.putBoolean(KEY_ENABLED, enabled)
        if (uid.isNotEmpty()) editor.putString(KEY_UID, uid)
        editor.putString(KEY_LEDGER, ledger.toJson())
        editor.apply()
    }

    @Synchronized
    fun recordCount(day: String, tzOffsetMinutes: Int, pkg: String, newSession: Boolean) {
        ledger.add(day, tzOffsetMinutes, pkg, newSession)
        prefs.edit().putString(KEY_LEDGER, ledger.toJson()).apply()
        schedulePing(day)
    }

    @Synchronized
    fun pending(): List<DayDelta> = ledger.pending()

    @Synchronized
    fun consume(done: List<DayDelta>) {
        ledger.consume(done)
        prefs.edit().putString(KEY_LEDGER, ledger.toJson()).apply()
    }

    private fun schedulePing(day: String) {
        if (pingScheduled) return
        pingScheduled = true
        pingHandler.postDelayed({
            pingScheduled = false
            val listener = ScrollDamageNotifier.listener ?: return@postDelayed
            val today = pending().firstOrNull { it.day == day } ?: return@postDelayed
            try {
                listener(
                    mapOf(
                        "day" to today.day,
                        "total" to today.total,
                        "perApp" to today.perApp,
                        "sessionCount" to today.sessions,
                    ),
                )
            } catch (e: Exception) {
                Log.e(TAG, "ping failed", e)
            }
        }, PING_DELAY_MS)
    }
}
