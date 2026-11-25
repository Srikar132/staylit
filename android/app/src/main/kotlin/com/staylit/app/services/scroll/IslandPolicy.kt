package com.staylit.app.services.scroll

/**
 * Pure (no Android types) rules for when the island pill is visible. The caller does the actual
 * showing and hiding and tells this class what happened.
 */
class IslandPolicy(
    /** Items in a session before the pill appears. */
    val minItems: Int = 5,
    /** No short-form activity for this long hides the pill (the session ended). */
    val idleMs: Long = 60_000,
) {
    enum class Action { SHOW, UPDATE, HIDE, NONE }

    var visible: Boolean = false
        private set

    private var lastActivityMs = Long.MIN_VALUE

    /** An item was counted. [sessionCount] includes it; [newSession] means it opened a new session. */
    fun onCounted(sessionCount: Int, newSession: Boolean, nowMs: Long, alwaysShow: Boolean = false): Action {
        lastActivityMs = nowMs
        if (newSession && visible) {
            // A new session starts from zero: hide, then wait for [minItems] again.
            visible = false
            if (!alwaysShow) return Action.HIDE
        }
        // During a break pass the pill (with its countdown) shows from the first item.
        if (!alwaysShow && sessionCount < minItems) return Action.NONE
        return if (visible) {
            Action.UPDATE
        } else {
            visible = true
            Action.SHOW
        }
    }

    /** Short-form view still on screen but nothing counted (same page, jitter). Keeps the session alive. */
    fun onActivity(nowMs: Long) {
        lastActivityMs = nowMs
    }

    /** The user is no longer in the short-form view (feed, DMs, other app, home, screen off, landscape). */
    fun onLeft(): Action = hide()

    /** Periodic check: hides the pill once the session has been idle for [idleMs]. */
    fun onIdleCheck(nowMs: Long): Action =
        if (visible && lastActivityMs != Long.MIN_VALUE && nowMs - lastActivityMs > idleMs) hide() else Action.NONE

    /** Feature off, service stopped, suppressed by a focus session or block overlay. */
    fun hide(): Action {
        if (!visible) return Action.NONE
        visible = false
        return Action.HIDE
    }

    fun reset() {
        visible = false
        lastActivityMs = Long.MIN_VALUE
    }
}
