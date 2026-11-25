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
 * data belongs to, the ledger of counts and the log of break-offer answers that Flutter has not stored yet.
 * Counts, package ids, enums and timestamps only.
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
        private const val KEY_EVENTS = "events"
        private const val KEY_PARENTAL = "parental_locked"
        private const val KEY_TODAY_DAY = "today_day"
        private const val KEY_TODAY_TOTAL = "today_total"

        /** Batch window for the "new data" ping to Flutter. */
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
    private val events = ScrollEventLog.fromJson(prefs.getString(KEY_EVENTS, null))
    private val pingHandler = Handler(Looper.getMainLooper())
    private var pingScheduled = false

    @Volatile
    private var enabled = prefs.getBoolean(KEY_ENABLED, false)

    /** A parent PIN protects the blocks: break passes must not be offered. Mirrored from Flutter. */
    @Volatile
    private var parentalLocked = prefs.getBoolean(KEY_PARENTAL, false)

    private var todayDay = prefs.getString(KEY_TODAY_DAY, "") ?: ""
    private var todayTotalValue = prefs.getInt(KEY_TODAY_TOTAL, 0)

    fun isEnabled(): Boolean = enabled

    fun isParentalLocked(): Boolean = parentalLocked

    /** Items counted on the local day [dayKey] (the ledger is consumed after each sync, this is not). */
    @Synchronized
    fun todayTotal(dayKey: String): Int = if (dayKey == todayDay) todayTotalValue else 0

    /**
     * Mirrors the Flutter setting. A different [uid] than the stored one drops unsynced data, so one
     * account's counts are never written to the next account on a shared device.
     */
    @Synchronized
    fun setEnabled(enabled: Boolean, uid: String, parentalLocked: Boolean? = null) {
        val storedUid = prefs.getString(KEY_UID, "") ?: ""
        if (uid.isNotEmpty() && storedUid.isNotEmpty() && uid != storedUid) {
            ledger.clear()
            events.clear()
            Log.d(TAG, "account changed, unsynced data dropped")
        }
        this.enabled = enabled
        if (parentalLocked != null) this.parentalLocked = parentalLocked
        val editor = prefs.edit()
        editor.putBoolean(KEY_ENABLED, enabled)
        editor.putBoolean(KEY_PARENTAL, this.parentalLocked)
        if (uid.isNotEmpty()) editor.putString(KEY_UID, uid)
        editor.putString(KEY_LEDGER, ledger.toJson())
        editor.putString(KEY_EVENTS, events.toJson())
        editor.apply()
    }

    @Synchronized
    fun recordCount(day: String, tzOffsetMinutes: Int, pkg: String, newSession: Boolean) {
        ledger.add(day, tzOffsetMinutes, pkg, newSession)
        if (day != todayDay) {
            todayDay = day
            todayTotalValue = 0
        }
        todayTotalValue += 1
        prefs.edit()
            .putString(KEY_LEDGER, ledger.toJson())
            .putString(KEY_TODAY_DAY, todayDay)
            .putInt(KEY_TODAY_TOTAL, todayTotalValue)
            .apply()
        schedulePing()
    }

    @Synchronized
    fun pending(): List<DayDelta> = ledger.pending()

    @Synchronized
    fun consume(done: List<DayDelta>) {
        ledger.consume(done)
        prefs.edit().putString(KEY_LEDGER, ledger.toJson()).apply()
    }

    @Synchronized
    fun recordEvent(event: ScrollEvent) {
        events.add(event)
        prefs.edit().putString(KEY_EVENTS, events.toJson()).apply()
        schedulePing()
    }

    @Synchronized
    fun pendingEvents(): List<ScrollEvent> = events.pending()

    @Synchronized
    fun consumeEvents(done: List<ScrollEvent>) {
        events.consume(done)
        prefs.edit().putString(KEY_EVENTS, events.toJson()).apply()
    }

    /** Tells Flutter (if its engine is alive) that there is something to pull. Batched. */
    private fun schedulePing() {
        if (pingScheduled) return
        pingScheduled = true
        pingHandler.postDelayed({
            pingScheduled = false
            val listener = ScrollDamageNotifier.listener ?: return@postDelayed
            val latest = pending().lastOrNull()
            try {
                listener(
                    mapOf(
                        "day" to (latest?.day ?: ""),
                        "total" to (latest?.total ?: 0),
                        "perApp" to (latest?.perApp ?: emptyMap<String, Int>()),
                        "sessionCount" to (latest?.sessions ?: 0),
                    ),
                )
            } catch (e: Exception) {
                Log.e(TAG, "ping failed", e)
            }
        }, PING_DELAY_MS)
    }
}
