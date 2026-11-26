package com.staylit.app.services.scroll

/** How the user answered a break offer. [wire] is what is stored and sent to Flutter. */
enum class OfferResponse(val wire: String) {
    BREAK("break"),
    KEEP("keep"),
    /** Ignored until the card timed out. */
    TIMEOUT("timeout"),
    /** Left the short-form view while the card was up. */
    LEFT("left"),
}

/**
 * Pure (no Android types) rules for the "Take a break?" offer.
 *
 * Deliberately flat: one threshold, repeated every [Config.repeatEvery] items, with a minimum gap
 * between offers. No tightening, no locking, no escalation ladder (AGENTS.md section 10: that design is
 * not decided).
 */
class InterventionPolicy(val config: Config = Config()) {

    data class Config(
        /** First offer at this many items in a session. */
        val firstAt: Int = 30,
        /** After an answer other than Take a break, offer again this many items later. */
        val repeatEvery: Int = 30,
        /** Never two offers closer than this. */
        val minGapMs: Long = 120_000,
        /** The card disappears after this long if ignored. */
        val autoDismissMs: Long = 12_000,
    )

    var offerActive: Boolean = false
        private set

    private var nextOfferAt = config.firstAt
    private var lastOfferMs = Long.MIN_VALUE

    /** An item was counted. Returns true if the card should be shown now. */
    fun onCounted(sessionCount: Int, newSession: Boolean, nowMs: Long): Boolean {
        if (newSession) nextOfferAt = config.firstAt
        if (offerActive) return false
        if (sessionCount < nextOfferAt) return false
        if (lastOfferMs != Long.MIN_VALUE && nowMs - lastOfferMs < config.minGapMs) return false
        return true
    }

    /** The card was put on screen. */
    fun onOfferShown(nowMs: Long) {
        offerActive = true
        lastOfferMs = nowMs
    }

    /** The user (or a timeout, or leaving) answered. */
    fun onAnswered(response: OfferResponse, sessionCount: Int) {
        offerActive = false
        nextOfferAt = when (response) {
            // Break ends the session: the next session starts from the first threshold again.
            OfferResponse.BREAK -> config.firstAt
            else -> sessionCount + config.repeatEvery
        }
    }

    /** Feature turned off or service stopped: forget the current offer state. */
    fun reset() {
        offerActive = false
        nextOfferAt = config.firstAt
        lastOfferMs = Long.MIN_VALUE
    }
}
