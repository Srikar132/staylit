package com.staylit.app.services.scroll

import android.content.Context
import android.content.SharedPreferences

/**
 * Persistent break passes (SharedPreferences `shortform_pass`): a timed allowance to watch short-form
 * content in a blocked app. Survives process death and service restarts. Only package ids and end times.
 */
class ShortFormPassStore private constructor(context: Context) {

    companion object {
        private const val PREFS = "shortform_pass"
        private const val KEY_LEDGER = "ledger"

        @Volatile
        private var INSTANCE: ShortFormPassStore? = null

        fun getInstance(context: Context): ShortFormPassStore =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: ShortFormPassStore(context.applicationContext).also { INSTANCE = it }
            }
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val ledger = PassLedger.fromJson(prefs.getString(KEY_LEDGER, null))

    @Synchronized
    fun start(pkg: String, minutes: Int, nowWallMs: Long): Boolean {
        val ok = ledger.start(pkg, minutes, nowWallMs)
        if (ok) save()
        return ok
    }

    @Synchronized
    fun isActive(pkg: String, nowWallMs: Long = System.currentTimeMillis()): Boolean = ledger.isActive(pkg, nowWallMs)

    @Synchronized
    fun remainingMs(pkg: String, nowWallMs: Long = System.currentTimeMillis()): Long = ledger.remainingMs(pkg, nowWallMs)

    @Synchronized
    fun activePackages(nowWallMs: Long = System.currentTimeMillis()): List<String> = ledger.activePackages(nowWallMs)

    @Synchronized
    fun cancel(pkg: String) {
        ledger.cancel(pkg)
        save()
    }

    @Synchronized
    fun cancelAll() {
        ledger.cancelAll()
        save()
    }

    private fun save() {
        prefs.edit().putString(KEY_LEDGER, ledger.toJson()).apply()
    }
}
