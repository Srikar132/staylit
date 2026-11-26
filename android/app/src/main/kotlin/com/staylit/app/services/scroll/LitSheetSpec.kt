package com.staylit.app.services.scroll

/** Which Lit sheet is showing. */
enum class SheetMode {
    OFFER, BLOCKED, TIMES_UP,

    /** The daily limit of an app was reached. */
    LIMIT,

    /** A blocked website was opened. */
    WEBSITE;

    /**
     * Stays until the user taps it. Unlike the short-form sheets it is not tied to one app's window, so a
     * window change (or the VPN path, which has no package at all) must not dismiss it.
     */
    val staysUntilAnswered: Boolean get() = this == LIMIT || this == WEBSITE
}

/**
 * Pure (no Android types) content of a Lit sheet: the words and which buttons each mode has.
 * Kept free of views so the copy and the rules (no passes during a focus session or under a parental
 * PIN) are unit tested on the JVM.
 */
data class SheetSpec(
    val mode: SheetMode,
    val title: String,
    val body: String,
    val primaryLabel: String,
    /** Text button under the primary one (OFFER only). */
    val secondaryLabel: String?,
    /** Pass lengths to offer as chips; empty when passes are not allowed. */
    val passMinutes: List<Int>,
    /** Muted line explaining why there are no chips, or null. */
    val hint: String?,
    /** True: dim the whole screen and take touches. False: a card the app stays usable around. */
    val modal: Boolean,
)

/** What the user needs to see about a short-form app. */
data class ShortFormInfo(
    val pkg: String,
    /** Dart/Firestore key parts, e.g. `Instagram` + `Reels` -> `Instagram_Reels`. */
    val platform: String,
    val feature: String,
    /** Short name used in copy: "Reels", "Shorts", "TikTok". */
    val label: String,
)

object ShortFormApps {
    private val apps = listOf(
        ShortFormInfo("com.instagram.android", "Instagram", "Reels", "Reels"),
        ShortFormInfo("com.google.android.youtube", "YouTube", "Shorts", "Shorts"),
        ShortFormInfo("com.zhiliaoapp.musically", "TikTok", "Videos", "TikTok"),
        ShortFormInfo("com.facebook.katana", "Facebook", "Reels", "Facebook Reels"),
    )

    fun forPackage(pkg: String): ShortFormInfo? = apps.firstOrNull { it.pkg == pkg }
}

object LitSheetSpec {

    private const val PIN_HINT = "Ask for the PIN in Blocks to take a break"
    private const val FOCUS_HINT = "Focus session in progress"

    fun offer(count: Int, label: String) = SheetSpec(
        mode = SheetMode.OFFER,
        title = "You have scrolled $count in a row",
        body = "Want a break from $label? Lit will block it until you turn it off in Blocks.",
        primaryLabel = "Take a break",
        secondaryLabel = "Keep scrolling",
        passMinutes = emptyList(),
        hint = null,
        modal = false,
    )

    fun blocked(label: String, focusActive: Boolean, parentalLocked: Boolean) = SheetSpec(
        mode = SheetMode.BLOCKED,
        title = "$label is blocked",
        body = "You asked Lit to keep you off it.",
        primaryLabel = "Go back",
        secondaryLabel = null,
        passMinutes = passes(focusActive, parentalLocked),
        hint = hint(focusActive, parentalLocked),
        modal = true,
    )

    fun timesUp(label: String, minutes: Int, focusActive: Boolean, parentalLocked: Boolean) = SheetSpec(
        mode = SheetMode.TIMES_UP,
        title = "Time's up",
        body = if (minutes > 0) "You watched $label for $minutes min." else "Your break from $label is over.",
        primaryLabel = "Done",
        secondaryLabel = null,
        passMinutes = passes(focusActive, parentalLocked),
        hint = hint(focusActive, parentalLocked),
        modal = true,
    )

    /** The daily limit of an app is used up. Informational: the app has already been sent Home. */
    fun limitReached(appLabel: String, limitMinutes: Int) = SheetSpec(
        mode = SheetMode.LIMIT,
        title = "$appLabel limit reached",
        body = if (limitMinutes > 0) {
            "You used it for $limitMinutes min today. It opens again tomorrow."
        } else {
            "You reached today's limit. It opens again tomorrow."
        },
        primaryLabel = "Got it",
        secondaryLabel = null,
        passMinutes = emptyList(),
        hint = null,
        modal = true,
    )

    /** A blocked website was opened. [domain] is shown as given (already trimmed to the host). */
    fun websiteBlocked(domain: String, focusActive: Boolean) = SheetSpec(
        mode = SheetMode.WEBSITE,
        title = "$domain is blocked",
        body = if (focusActive) "Blocked during your focus session." else "You asked Lit to keep you off it.",
        primaryLabel = "Got it",
        secondaryLabel = null,
        passMinutes = emptyList(),
        hint = null,
        modal = true,
    )

    /** The host of a URL or bare domain, for display: no scheme, path, query, `www.`. Never empty. */
    fun displayDomain(urlOrDomain: String): String {
        var s = urlOrDomain.trim()
        s = s.substringAfter("://", s)
        s = s.substringBefore('/').substringBefore('?').substringBefore('#')
        s = s.removePrefix("www.")
        return s.ifBlank { urlOrDomain.trim().ifBlank { "This website" } }
    }

    /** Passes loosen a block: never during a focus session, never when a parent PIN protects the block. */
    private fun passes(focusActive: Boolean, parentalLocked: Boolean): List<Int> =
        if (focusActive || parentalLocked) emptyList() else PassLedger.ALLOWED_MINUTES.toList()

    private fun hint(focusActive: Boolean, parentalLocked: Boolean): String? = when {
        focusActive -> FOCUS_HINT
        parentalLocked -> PIN_HINT
        else -> null
    }
}
