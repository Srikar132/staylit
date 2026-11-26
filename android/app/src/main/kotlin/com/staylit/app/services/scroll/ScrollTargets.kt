package com.staylit.app.services.scroll

/** How to confirm that an allow-listed app is showing its short-form view. */
enum class ShortFormCheck {
    /** Existing `detectYouTubeShortsEnhanced()`. */
    YOUTUBE_SHORTS,

    /** Existing `detectInstagramReels()`. */
    INSTAGRAM_REELS,

    /** The whole app is short-form (TikTok), as the blocker already assumes. */
    ALWAYS,

    /** Best effort: the selected tab is "Reels" (Facebook ids are obfuscated). */
    FACEBOOK_REELS_TAB,
}

/**
 * Table of the apps Scroll damage counts. Only these packages are ever looked at. To switch one off
 * after device testing, remove its row.
 */
object ScrollTargets {

    private val checks: Map<String, ShortFormCheck> = mapOf(
        "com.instagram.android" to ShortFormCheck.INSTAGRAM_REELS,
        "com.google.android.youtube" to ShortFormCheck.YOUTUBE_SHORTS,
        "com.zhiliaoapp.musically" to ShortFormCheck.ALWAYS,
        "com.facebook.katana" to ShortFormCheck.FACEBOOK_REELS_TAB,
    )

    fun checkFor(pkg: String): ShortFormCheck? = checks[pkg]

    fun isTarget(pkg: String): Boolean = checks.containsKey(pkg)
}
