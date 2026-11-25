package com.staylit.app.services.scroll

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Glue between the counter and what the user sees: the island pill ([ScrollIsland]) and the break offer
 * ([InterventionCard]). The rules themselves live in the pure [IslandPolicy] and [InterventionPolicy].
 *
 * Every entry point is safe to call at any time and never throws into the accessibility service.
 */
class ScrollDamageUi(
    private val service: AccessibilityService,
    private val store: ScrollDamageStore,
    /** Take a break: go to the home screen. Returns false if the system refused. */
    private val goHome: () -> Boolean,
    /** True while a focus session or a Staylit block overlay owns the screen: show nothing. */
    private val isSuppressed: () -> Boolean,
    /** Asks the service whether [pkg]'s short-form view is on screen right now (no cache). */
    private val stillInShortForm: (String) -> Boolean,
) {
    private companion object {
        const val TAG = "ScrollDamage"

        /** Window changes from these never mean the user left the app. */
        val IGNORED_WINDOW_PACKAGES = setOf("com.android.systemui", "android")

        const val RECHECK_DELAY_MS = 600L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val island = ScrollIsland(service)
    private val card = InterventionCard(service)
    private val islandPolicy = IslandPolicy()
    private val intervention = InterventionPolicy()

    private var currentPkg: String? = null
    private var sessionCount = 0

    // The offer currently on screen (captured when it appeared).
    private var offerTs = 0L
    private var offerDay = ""
    private var offerTz = 0
    private var offerPkg = ""
    private var offerCount = 0

    private val idleRunnable = Runnable { onIdle() }
    private val recheckRunnable = Runnable { recheck() }

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            hideAll()
        }
    }
    private var receiverRegistered = false

    init {
        try {
            ContextCompat.registerReceiver(
                service,
                screenOffReceiver,
                IntentFilter(Intent.ACTION_SCREEN_OFF),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            receiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "screen-off receiver failed", e)
        }
    }

    /** An item was counted. */
    fun onCounted(pkg: String, result: ScrollCounterEngine.Result, nowMs: Long, wallMs: Long) {
        try {
            currentPkg = pkg
            sessionCount = result.sessionCount
            scheduleIdle()

            if (isSuppressed()) {
                hidePill()
                return
            }

            val level = ScrollMoodLevel.forCount(result.sessionCount)
            when (islandPolicy.onCounted(result.sessionCount, result.newSession, nowMs)) {
                IslandPolicy.Action.SHOW -> island.show(result.sessionCount, level)
                IslandPolicy.Action.UPDATE -> island.update(result.sessionCount, level)
                IslandPolicy.Action.HIDE -> island.hide()
                IslandPolicy.Action.NONE -> Unit
            }

            if (intervention.onCounted(result.sessionCount, result.newSession, nowMs)) {
                offer(pkg, result, nowMs, wallMs)
            }
        } catch (e: Exception) {
            Log.e(TAG, "ui update failed", e)
        }
    }

    /** Short-form view still showing but nothing counted: the session is alive. */
    fun onActivity(pkg: String, nowMs: Long) {
        currentPkg = pkg
        islandPolicy.onActivity(nowMs)
        scheduleIdle()
    }

    /** The user is no longer in the short-form view. */
    fun onLeftShortForm() {
        try {
            hidePill()
            if (card.isShown) card.answer(OfferResponse.LEFT)
            currentPkg = null
            handler.removeCallbacks(idleRunnable)
            handler.removeCallbacks(recheckRunnable)
        } catch (e: Exception) {
            Log.e(TAG, "leave failed", e)
        }
    }

    /** A different app or the launcher came to the front. */
    fun onWindowChanged(pkg: String) {
        val current = currentPkg ?: return
        // Our own windows (the card) must never count as "the user left".
        if (pkg == current || pkg == service.packageName) return
        if (pkg in IGNORED_WINDOW_PACKAGES || pkg.contains("inputmethod")) return
        onLeftShortForm()
    }

    /**
     * Something happened inside the same app (a tab tap, a new screen). Scrolling is what normally tells
     * us the user left Reels/Shorts, but a tap on another tab does not scroll: look again, once, shortly.
     */
    fun onPossibleViewChange(pkg: String) {
        if (currentPkg != pkg || !island.isShown) return
        handler.removeCallbacks(recheckRunnable)
        handler.postDelayed(recheckRunnable, RECHECK_DELAY_MS)
    }

    fun onConfigurationChanged() {
        try {
            island.onConfigurationChanged()
        } catch (e: Exception) {
            Log.e(TAG, "config change failed", e)
        }
    }

    /** Feature off, service interrupted or screen off: nothing stays on screen. */
    fun hideAll() {
        try {
            hidePill()
            if (card.isShown) card.answer(OfferResponse.LEFT)
            handler.removeCallbacks(idleRunnable)
            handler.removeCallbacks(recheckRunnable)
        } catch (e: Exception) {
            Log.e(TAG, "hide failed", e)
        }
    }

    /** Feature off: hide and forget all session state. */
    fun reset() {
        // Turned off with an offer on screen: that is not an answer, so log nothing.
        card.dismissSilently()
        hideAll()
        islandPolicy.reset()
        intervention.reset()
        currentPkg = null
        sessionCount = 0
    }

    /** Service stopping: remove everything without logging an answer. */
    fun release() {
        handler.removeCallbacksAndMessages(null)
        card.dismissSilently()
        island.hide()
        islandPolicy.reset()
        intervention.reset()
        if (receiverRegistered) {
            try {
                service.unregisterReceiver(screenOffReceiver)
            } catch (e: Exception) {
                // Already unregistered.
            }
            receiverRegistered = false
        }
    }

    // ---- internals

    private fun hidePill() {
        islandPolicy.hide()
        island.hide()
    }

    private fun scheduleIdle() {
        handler.removeCallbacks(idleRunnable)
        handler.postDelayed(idleRunnable, islandPolicy.idleMs + 1_000)
    }

    private fun onIdle() {
        try {
            if (islandPolicy.onIdleCheck(SystemClock.elapsedRealtime()) == IslandPolicy.Action.HIDE) island.hide()
        } catch (e: Exception) {
            Log.e(TAG, "idle check failed", e)
        }
    }

    private fun recheck() {
        val pkg = currentPkg ?: return
        try {
            if (!stillInShortForm(pkg)) onLeftShortForm()
        } catch (e: Exception) {
            Log.e(TAG, "recheck failed", e)
        }
    }

    private fun offer(pkg: String, result: ScrollCounterEngine.Result, nowMs: Long, wallMs: Long) {
        offerTs = wallMs
        offerDay = result.day
        offerTz = result.tzOffsetMinutes
        offerPkg = pkg
        offerCount = result.sessionCount

        val shown = card.show(result.sessionCount, intervention.config.autoDismissMs) { response ->
            onAnswered(response)
        }
        if (shown) intervention.onOfferShown(nowMs)
    }

    private fun onAnswered(response: OfferResponse) {
        intervention.onAnswered(response, offerCount)
        store.recordEvent(
            ScrollEvent(
                ts = offerTs,
                day = offerDay,
                tzOffsetMinutes = offerTz,
                pkg = offerPkg,
                sessionCount = offerCount,
                threshold = intervention.config.firstAt,
                response = response.wire,
            ),
        )
        Log.d(TAG, "OFFER ${response.wire} pkg=$offerPkg session=$offerCount")
        if (response == OfferResponse.BREAK) {
            hidePill()
            // If the system refuses (screen pinning, some OEMs) the card is already gone: just carry on.
            goHome()
        }
    }
}
