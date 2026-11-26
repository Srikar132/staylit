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
import com.staylit.app.R

/**
 * Glue between the counter, the short-form block and what the user sees:
 * the island ([ScrollIsland]), the Lit sheet ([LitSheet]: offer, blocked, time's up) and break passes.
 * The rules live in the pure [IslandPolicy], [InterventionPolicy], [PassLedger] and [LitSheetSpec].
 *
 * Flow: scroll count reaches the threshold -> sheet "Take a break?" -> Take a break switches the
 * short-form block ON and leaves the app -> opening the blocked app shows the sheet again, with
 * 5 / 10 / 20 minute passes -> a pass runs, the island shows the countdown, then "Time's up".
 *
 * Every entry point is safe to call at any time and never throws into the accessibility service.
 */
class ScrollDamageUi(
    private val service: AccessibilityService,
    private val store: ScrollDamageStore,
    private val passStore: ShortFormPassStore,
    /** Take the user out of [pkg]'s short-form view (the app's Home, or the launcher). */
    private val leaveShortForm: (String) -> Unit,
    private val isFocusActive: () -> Boolean,
    /** A website / other Staylit block overlay owns the screen. */
    private val isBlockOverlayShowing: () -> Boolean,
    /** Is the short-form block for [pkg] switched on right now? */
    private val isBlockOn: (String) -> Boolean,
    /** Asks the service whether [pkg]'s short-form view is on screen right now (no cache). */
    private val stillInShortForm: (String) -> Boolean,
    /** A swipe is in progress (do not yank the screen in the middle of it). */
    private val isSwiping: () -> Boolean,
) : ScrollIsland.Host {

    private companion object {
        const val TAG = "ScrollDamage"

        /** Window changes from these never mean the user left the app. */
        val IGNORED_WINDOW_PACKAGES = setOf("com.android.systemui", "android")

        const val RECHECK_DELAY_MS = 600L

        /** After a sheet appears, window events from our own navigation are not "the user left". */
        const val SHEET_GRACE_MS = 1_500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val island = ScrollIsland(service, this)
    private val sheet = LitSheet(service)
    private val islandPolicy = IslandPolicy()
    private val intervention = InterventionPolicy()

    // Session in front of the user.
    private var currentPkg: String? = null
    private var sessionCount = 0
    private var sessionStartMs = SystemClock.elapsedRealtime()

    // The offer currently on screen (captured when it appeared).
    private var offerTs = 0L
    private var offerDay = ""
    private var offerTz = 0
    private var offerPkg = ""
    private var offerCount = 0

    // The blocked / time's-up sheet currently on screen.
    private var sheetPkg = ""
    private var sheetShownAt = 0L

    private val passMinutes = HashMap<String, Int>()
    private val expiry = HashMap<String, Runnable>()
    private var lastEventTs = 0L

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
        restorePasses()
    }

    // ------------------------------------------------------------------ island host

    override fun cardState(): IslandCardState = IslandCardState(
        sessionCount = sessionCount,
        todayTotal = store.todayTotal(ScrollDayKey.of(System.currentTimeMillis())),
        sessionMinutes = IslandCardSpec.sessionMinutes(sessionStartMs, SystemClock.elapsedRealtime()),
        moodLevel = ScrollMoodLevel.forCount(sessionCount),
        passRemainingMs = passRemainingMs(),
    )

    override fun passRemainingMs(): Long? {
        val pkg = currentPkg ?: return null
        val ms = passStore.remainingMs(pkg)
        return if (ms > 0) ms else null
    }

    override fun onTakeBreak() {
        val pkg = currentPkg ?: return
        intervention.onAnswered(OfferResponse.BREAK, sessionCount)
        logEvent("island", OfferResponse.BREAK.wire, pkg, 0, sessionCount)
        takeBreak(pkg)
    }

    override fun onEndBreakEarly() {
        val pkg = currentPkg ?: return
        passStore.cancel(pkg)
        cancelExpiry(pkg)
        logEvent("pass", "ended_early", pkg, passMinutes.remove(pkg) ?: 0, sessionCount)
        island.refresh()
    }

    // ------------------------------------------------------------------ counter events

    /** An item was counted. */
    fun onCounted(pkg: String, result: ScrollCounterEngine.Result, nowMs: Long, wallMs: Long) {
        try {
            currentPkg = pkg
            sessionCount = result.sessionCount
            if (result.newSession) sessionStartMs = nowMs
            scheduleIdle()

            if (isFocusActive() || isBlockOverlayShowing()) {
                hidePill()
                return
            }
            // Block sheets own the screen; no pill or offer on top of them.
            if (sheet.isShown && sheet.mode != SheetMode.OFFER) return

            val passActive = passStore.isActive(pkg)
            val level = ScrollMoodLevel.forCount(result.sessionCount)
            when (islandPolicy.onCounted(result.sessionCount, result.newSession, nowMs, alwaysShow = passActive)) {
                IslandPolicy.Action.SHOW -> island.show(result.sessionCount, level)
                IslandPolicy.Action.UPDATE -> island.update(result.sessionCount, level)
                IslandPolicy.Action.HIDE -> island.hide()
                IslandPolicy.Action.NONE -> Unit
            }

            // A pass is a timed allowance the user chose: no offer while it runs.
            if (!passActive && intervention.onCounted(result.sessionCount, result.newSession, nowMs)) {
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
            if (sheet.isShown && sheet.mode == SheetMode.OFFER) sheet.answer(LitSheet.Result(LitSheet.Kind.LEFT))
            currentPkg = null
            handler.removeCallbacks(idleRunnable)
            handler.removeCallbacks(recheckRunnable)
        } catch (e: Exception) {
            Log.e(TAG, "leave failed", e)
        }
    }

    /** A window of [pkg] came to the front. */
    fun onWindowChanged(pkg: String) {
        try {
            if (pkg == service.packageName || pkg in IGNORED_WINDOW_PACKAGES || pkg.contains("inputmethod")) return

            // A blocked / time's-up sheet is dismissed once the user really goes elsewhere.
            if (sheet.isShown && sheet.mode != SheetMode.OFFER && pkg != sheetPkg &&
                SystemClock.elapsedRealtime() - sheetShownAt > SHEET_GRACE_MS
            ) {
                sheet.dismissSilently()
            }

            val current = currentPkg ?: return
            if (pkg == current) return
            onLeftShortForm()
        } catch (e: Exception) {
            Log.e(TAG, "window change failed", e)
        }
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

    // ------------------------------------------------------------------ block sheet and passes

    /**
     * The short-form block fired for [pkg]: show the blocked sheet (Go back + 5 / 10 / 20 min passes).
     * Returns false if [pkg] is not one of the four short-form apps, so the caller can fall back.
     */
    fun showBlocked(pkg: String): Boolean {
        val info = ShortFormApps.forPackage(pkg) ?: return false
        return try {
            if (sheet.isShown) {
                if (sheet.mode == SheetMode.BLOCKED && sheetPkg == pkg) return true
                if (sheet.mode == SheetMode.OFFER) {
                    sheet.answer(LitSheet.Result(LitSheet.Kind.LEFT))
                } else {
                    sheet.dismissSilently()
                }
            }
            hidePill()
            val spec = LitSheetSpec.blocked(info.label, isFocusActive(), store.isParentalLocked())
            sheetPkg = pkg
            sheetShownAt = SystemClock.elapsedRealtime()
            val shown = sheet.show(spec, R.drawable.lit_focused_sheet, 0) { r -> onBlockedResult(pkg, "go_back", r) }
            if (shown) logEvent("blocked", "shown", pkg, 0, 0)
            shown
        } catch (e: Exception) {
            Log.e(TAG, "blocked sheet failed", e)
            false
        }
    }

    private fun onBlockedResult(pkg: String, primaryResponse: String, r: LitSheet.Result) {
        when (r.kind) {
            LitSheet.Kind.PRIMARY -> logEvent("blocked", primaryResponse, pkg, 0, 0)
            LitSheet.Kind.PASS -> startPass(pkg, r.minutes)
            else -> Unit
        }
    }

    private fun startPass(pkg: String, minutes: Int) {
        // Never while a focus session runs or a parent PIN protects the block (the sheet hides the chips too).
        if (isFocusActive() || store.isParentalLocked()) return
        if (!passStore.start(pkg, minutes, System.currentTimeMillis())) return
        passMinutes[pkg] = minutes
        logEvent("pass", "start", pkg, minutes, 0)
        scheduleExpiry(pkg)
        island.refresh()
    }

    private fun restorePasses() {
        for (pkg in passStore.activePackages()) scheduleExpiry(pkg)
    }

    private fun scheduleExpiry(pkg: String) {
        cancelExpiry(pkg)
        val ms = passStore.remainingMs(pkg)
        if (ms <= 0) return
        val r = Runnable { onPassExpired(pkg) }
        expiry[pkg] = r
        handler.postDelayed(r, ms + 250)
    }

    private fun cancelExpiry(pkg: String) {
        expiry.remove(pkg)?.let { handler.removeCallbacks(it) }
    }

    private fun onPassExpired(pkg: String) {
        try {
            expiry.remove(pkg)
            if (passStore.isActive(pkg)) {
                scheduleExpiry(pkg) // clock skew: not over yet
                return
            }
            passStore.cancel(pkg)
            val minutes = passMinutes.remove(pkg) ?: 0
            logEvent("pass", "expired", pkg, minutes, sessionCount)
            island.refresh()

            // Only act if the user is still in that app's short-form view; otherwise the normal block
            // applies the next time they open it.
            if (currentPkg != pkg || !isBlockOn(pkg) || !stillInShortForm(pkg)) return
            val finish = { showTimesUp(pkg, minutes) }
            if (isSwiping()) handler.postDelayed(finish, 500) else finish()
        } catch (e: Exception) {
            Log.e(TAG, "pass expiry failed", e)
        }
    }

    private fun showTimesUp(pkg: String, minutes: Int) {
        val info = ShortFormApps.forPackage(pkg) ?: return
        hidePill()
        leaveShortForm(pkg)
        if (sheet.isShown) sheet.dismissSilently()
        val spec = LitSheetSpec.timesUp(info.label, minutes, isFocusActive(), store.isParentalLocked())
        sheetPkg = pkg
        sheetShownAt = SystemClock.elapsedRealtime()
        sheet.show(spec, R.drawable.lit_focused_sheet, 0) { r -> onBlockedResult(pkg, "done", r) }
    }

    // ------------------------------------------------------------------ offer and break

    private fun offer(pkg: String, result: ScrollCounterEngine.Result, nowMs: Long, wallMs: Long) {
        val info = ShortFormApps.forPackage(pkg) ?: return
        if (sheet.isShown) return
        island.collapse(instant = true)

        offerTs = nextTs(wallMs)
        offerDay = result.day
        offerTz = result.tzOffsetMinutes
        offerPkg = pkg
        offerCount = result.sessionCount

        val spec = LitSheetSpec.offer(result.sessionCount, info.label)
        val shown = sheet.show(spec, R.drawable.lit_scroll_pill, intervention.config.autoDismissMs) { r ->
            onOfferResult(r)
        }
        if (shown) intervention.onOfferShown(nowMs)
    }

    private fun onOfferResult(r: LitSheet.Result) {
        val response = when (r.kind) {
            LitSheet.Kind.PRIMARY -> OfferResponse.BREAK
            LitSheet.Kind.TIMEOUT -> OfferResponse.TIMEOUT
            LitSheet.Kind.LEFT -> OfferResponse.LEFT
            else -> OfferResponse.KEEP
        }
        intervention.onAnswered(response, offerCount)
        if (store.isEnabled()) {
            store.recordEvent(
                ScrollEvent(
                    ts = offerTs,
                    day = offerDay,
                    tzOffsetMinutes = offerTz,
                    pkg = offerPkg,
                    sessionCount = offerCount,
                    threshold = intervention.config.firstAt,
                    response = response.wire,
                    kind = "offer",
                ),
            )
        }
        Log.d(TAG, "OFFER ${response.wire} pkg=$offerPkg session=$offerCount")
        if (response == OfferResponse.BREAK) takeBreak(offerPkg)
    }

    /**
     * Take a break: the app's short-form block goes ON (both native stores; Flutter mirrors it to Firestore
     * so the Blocks tab shows the switch), any running pass ends, and the user is taken out of the app.
     */
    private fun takeBreak(pkg: String) {
        val info = ShortFormApps.forPackage(pkg)
        if (info != null) ShortFormBlockBridge.enable(service, info)
        passStore.cancel(pkg)
        cancelExpiry(pkg)
        passMinutes.remove(pkg)
        hidePill()
        leaveShortForm(pkg)
    }

    // ------------------------------------------------------------------ teardown

    /** Screen off, service interrupted or feature turned off: nothing stays on screen. */
    fun hideAll() {
        try {
            hidePill()
            if (sheet.isShown) {
                if (sheet.mode == SheetMode.OFFER) sheet.answer(LitSheet.Result(LitSheet.Kind.LEFT)) else sheet.dismissSilently()
            }
            handler.removeCallbacks(idleRunnable)
            handler.removeCallbacks(recheckRunnable)
        } catch (e: Exception) {
            Log.e(TAG, "hide failed", e)
        }
    }

    /** Scroll damage turned off: hide and forget the session. Passes and the block itself are not touched. */
    fun reset() {
        sheet.dismissSilently()
        hideAll()
        islandPolicy.reset()
        intervention.reset()
        currentPkg = null
        sessionCount = 0
    }

    /** Service stopping: remove everything without logging an answer. */
    fun release() {
        handler.removeCallbacksAndMessages(null)
        sheet.dismissSilently()
        island.hide()
        islandPolicy.reset()
        intervention.reset()
        expiry.clear()
        if (receiverRegistered) {
            try {
                service.unregisterReceiver(screenOffReceiver)
            } catch (e: Exception) {
                // Already unregistered.
            }
            receiverRegistered = false
        }
    }

    // ------------------------------------------------------------------ internals

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

    /** Unique, increasing timestamps so the Firestore document id (= ts) never collides. */
    private fun nextTs(wallMs: Long): Long {
        lastEventTs = if (wallMs > lastEventTs) wallMs else lastEventTs + 1
        return lastEventTs
    }

    /** Counts, package id, enums and a timestamp only. Only recorded while Scroll damage is on. */
    private fun logEvent(kind: String, response: String, pkg: String, minutes: Int, count: Int) {
        if (!store.isEnabled()) return
        val wall = System.currentTimeMillis()
        store.recordEvent(
            ScrollEvent(
                ts = nextTs(wall),
                day = ScrollDayKey.of(wall),
                tzOffsetMinutes = ScrollDayKey.offsetMinutes(wall),
                pkg = pkg,
                sessionCount = count,
                threshold = intervention.config.firstAt,
                response = response,
                kind = kind,
                minutes = minutes,
            ),
        )
        Log.d(TAG, "EVENT $kind/$response pkg=$pkg minutes=$minutes")
    }
}
