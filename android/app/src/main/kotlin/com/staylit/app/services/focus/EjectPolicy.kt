package com.staylit.app.services.focus

/** What to do about a full-screen blocked app that is still there after the last attempt. */
enum class EjectStep {
    /** Bring Staylit to the front (the original behaviour). */
    BRING_STAYLIT_FRONT,

    /** Press Home. Works when Staylit is itself floating and "bring to front" does nothing. */
    GO_HOME,

    /** Last resort: cover the blocked window until it leaves. */
    COVER_FULL_SCREEN,
}

/**
 * Pure (no Android types) escalation for a full-screen blocked app, JVM tested.
 *
 * Bringing Staylit to the front is a no-op when Staylit is already a visible floating window, and the
 * old code repeated that no-op forever. Now each retry is a different, stronger action.
 */
object EjectPolicy {

    /**
     * @param failedAttempts how many eject actions were already tried for this blocked window
     * @param staylitFloating Staylit itself is on screen as a non-full-screen (floating) window:
     *   "bring to front" cannot work, so that step is skipped
     */
    fun stepFor(failedAttempts: Int, staylitFloating: Boolean): EjectStep {
        val n = failedAttempts.coerceAtLeast(0) + if (staylitFloating) 1 else 0
        return when {
            n <= 0 -> EjectStep.BRING_STAYLIT_FRONT
            n == 1 -> EjectStep.GO_HOME
            else -> EjectStep.COVER_FULL_SCREEN
        }
    }

    /** True if one of our own application windows is on screen but does not fill the display. */
    fun isStaylitFloating(
        windows: List<WindowSnapshot>,
        ownPackage: String,
        screenWidth: Int,
        screenHeight: Int,
    ): Boolean = windows.any {
        it.kind == WindowKind.APPLICATION &&
            it.packageName == ownPackage &&
            !VisibleWindowEvaluator.isFullScreen(it.bounds, screenWidth, screenHeight)
    }
}
