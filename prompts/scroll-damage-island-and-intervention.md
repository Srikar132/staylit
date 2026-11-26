# Scroll damage phases 2 + 3: "dynamic island" count pill and break offer (issue #41)

Builds on phase 1 (PR #42, branch `feat/scroll-damage-native`). Same branch, same PR.

## Goal

**Phase 2.** While the user scrolls short-form content, a small black pill sits at the top of the screen
**around the camera cutout** (a "dynamic island", positioned with the Android `DisplayCutout` API) and shows
the **live count of this scroll session** next to a tiny Lit. It appears after 5 items, changes mood colour
with the count, and disappears when they leave the short-form view, when the feature is turned off, or when
the service stops.

**Phase 3.** At a threshold (default 30 items in a session) a small bottom card offers **"Take a break?"**
with **Take a break** / **Keep scrolling**. The answer is logged (counts and timestamps only). This is the
first user-response feedback signal for the personalization dataset (issue #37).

## Skills / docs read

- `AGENTS.md` sections 2, 3, 5, 10, 11. Overlay + service work is on the no-exceptions approval list.
  **Section 10: the escalation ladder is undecided, so the intervention below is the simplest possible
  proposal and needs your sign-off.**
- Android docs checked: `DisplayCutout` (`boundingRects`, `getBoundingRectTop`, `safeInset*`),
  `WindowManager.LayoutParams.layoutInDisplayCutoutMode` (`SHORT_EDGES` API 28, `ALWAYS` API 30),
  `WindowMetrics.windowInsets` (API 30) / `View.rootWindowInsets` (API 23+, cutout from 28),
  `TYPE_ACCESSIBILITY_OVERLAY` (no extra permission), `AccessibilityService.performGlobalAction`.
- Skills while building: `dart-add-unit-test`, `firebase-security-rules-auditor`, `code-review`.

## Code inspected (and what it showed)

- `services/focus/FocusWindowCover.kt` already adds `TYPE_ACCESSIBILITY_OVERLAY` windows with
  `FLAG_NOT_FOCUSABLE | FLAG_LAYOUT_IN_SCREEN | FLAG_LAYOUT_NO_LIMITS` from the accessibility service, and builds
  views in code (no XML). The island copies that approach. No manifest or permission change.
- `services/overlay/SimpleBlockOverlay.kt` uses `TYPE_APPLICATION_OVERLAY` (needs the "display over other
  apps" permission) and `MATCH_PARENT`. Not reused: wrong window type for a tiny always-passive pill, and it is
  tied to the blocking flow.
- Phase 1 pieces to hook into: `ScrollCounterEngine` (`sessionCount`, `newSession`, `Outcome`),
  `StaylitAccessibilityService.settleScrollBurst()`, `setScrollDamageEnabled()`, `onUnbind()`.
- `ScrollMood` (Dart) thresholds 20 / 60 / 120 / 200. Kotlin gets a pure twin plus a test that pins the same
  values.
- `minSdk` = 24 (Flutter default), so the cutout API does not exist below 28: fallback needed.
- `assets/images/lit_scroll.webp` exists (scowling pose). Copied into `res/drawable-nodpi` for the native view.
- **No "study app" setting exists anywhere** (`grep studyApp` is empty). The issue's "back to study opens the
  user's configured study app" has nothing to open. See decisions.
- `firestore.rules`: owner-only pattern from `scrollStats`.

## Design

### Phase 2: the island

New files in `services/scroll/`:

| File | Pure? | Job |
|---|---|---|
| `IslandGeometry.kt` | yes | cutout rects + screen size + density -> where the pill goes and how wide |
| `ScrollMoodLevel.kt` | yes | count -> mood level 1..5 (same thresholds as Dart) |
| `IslandPolicy.kt` | yes | when the pill is shown / hidden (min items, idle, negative check) |
| `ScrollIsland.kt` | no | the window + native views, animation, add/remove safely |

**Geometry (`DisplayCutout`).**
1. Read the cutout: API 30+ `windowManager.currentWindowMetrics.windowInsets.displayCutout`; API 28-29
   `view.rootWindowInsets?.displayCutout` after the pill view is attached (re-read on first
   `OnApplyWindowInsetsListener`); below 28 none.
2. Take the **top** bounding rect (`boundingRectTop`, or the rect with `top == 0`).
3. **Centred cutout** (|rect.centerX - screenWidth/2| <= 12% of width, typical camera hole or notch):
   the pill **wraps** it: `width = cutout.width + 2 x 52dp`, `height = max(cutout.bottom + 2dp, 28dp)`,
   `y = 0`, x-offset = `rect.centerX - screenWidth/2`. Left half shows the count, right half shows Lit; the
   camera hole sits in the pill's black middle, which is the island look. Window uses
   `layoutInDisplayCutoutMode = ALWAYS` (API 30+) / `SHORT_EDGES` (28-29) so it may draw into the cutout area.
4. **No cutout, off-centre punch hole (corner, left, right), API < 28:** a **compact pill** (about 96dp wide),
   centred, `y = max(statusBarHeight, bottom of any cutout rect it would overlap) + 4dp`, so it never covers
   the camera or the clock.
5. **Landscape** (width > height): hide (short-form is portrait; avoids covering a landscape cutout).
6. Geometry is recomputed on `onConfigurationChanged` (rotation, fold/unfold, display size, font scale) and on
   the first window-insets callback. Foldables have different cutouts per display: recompute, never cache.

**Pill content.** Pure black pill (the design system's "near-black emphasis surface"; value read from
`lib/core/theme` palette `ink`, put in `res/values/colors.xml`), white count text (tabular, `sp` with a cap on
font scale so it never outgrows the cutout height), a small mood dot in the accent orange, turning red at mood
4-5. Lit icon is decorative. All native views, no Flutter engine. Text is only the session count, e.g. `37`.

**Passive window.** `FLAG_NOT_TOUCHABLE | FLAG_NOT_FOCUSABLE`: touches fall through to the app, so the pill can
never block a swipe, and `importantForAccessibility = no` so TalkBack does not read it on every count.

**Show / hide rules (`IslandPolicy`, unit tested).**
- Show once the session has >= 5 items (config).
- Update the number on every `COUNTED`; small scale "bump" animation, skipped when the system animator scale is 0
  (reduce motion).
- Hide immediately on: feature turned off, service unbound/interrupted, screen off, a settle outcome of
  `NOT_SHORT_FORM` (user went to the feed / DMs / another tab), a window-state change to a different
  non-system app or the launcher, landscape, or 60 s with no short-form activity (session ended).
- A new session starts hidden again at 0 until 5 items.
- Never shown while a focus session is active or a Staylit block overlay is up (blocking has priority,
  "Focus > Limits > Shorts > Websites" stays untouched).

### Phase 3: the break offer

New files: `InterventionPolicy.kt` (pure), `InterventionCard.kt` (window + views), `ScrollEventLog.kt` (pure ring
buffer + JSON, like `ScrollLedger`).

**Policy (deliberately flat, no ladder):**
- Offer when `sessionCount >= nextOfferAt`, first at N = 30.
- **Keep scrolling** (or ignoring it for 12 s, or leaving the app): offer again after another N items
  (`nextOfferAt += N`), never twice within 2 minutes. A new session resets `nextOfferAt` to N.
- **Take a break:** `performGlobalAction(GLOBAL_ACTION_HOME)`, hide pill and card, session counted as ended.
- No offer during a focus session, while a block overlay is up, or when the feature is off.
- No tightening, shaming, locking or longer breaks. That would be an escalation design and is not decided.

**Card.** Bottom of screen, above the nav area, 16dp margins, near-black card, white text:
"You have scrolled 30 in a row. Take a break?" + two buttons (Take a break primary orange, Keep scrolling text).
`TYPE_ACCESSIBILITY_OVERLAY`, `FLAG_NOT_FOCUSABLE` (never steals focus or the keyboard), touchable only on the
card. Content descriptions set, announced once with `announceForAccessibility`.

**Response log (feeds #37).** Each offer ends with a row
`{ts, day, tzOffsetMinutes, pkg, sessionCount, threshold, response: break | keep | timeout | left}`.
Counts, package id, enum and timestamps only. Stored natively in a ring buffer (max 200, SharedPreferences),
pulled by Flutter with the **same pull -> write -> consume pattern** as the counts, written to
`scrollEvents/{uid}/items/{ts}` (`set`, document id = timestamp, so a retry after a crash overwrites instead of
double counting).

### Flutter side

- `ScrollEvent` model, `ScrollStatsRepository.addEvents` (set with merge), second `ScrollFlusher` instance in the
  sync provider for events. Channel gets `getPendingScrollEvents` / `consumeScrollEvents`.
- Rules: `match /scrollEvents/{uid}/items/{id} { allow read, write: if isOwner(uid); }`, redeployed with
  `firebase deploy --only firestore --project staylit-4064f` (additive).
- No Home UI change. (Optional later: show the response history.)

## Decisions needing your sign-off (approve = accept these defaults)

1. **Island shows the session count**, not the day total (the Home card already shows the day total).
2. **Threshold N = 30, repeat every N more, min 2 min between offers, 12 s auto-dismiss.** Constants in one object,
   no settings UI yet.
3. **Take a break = go to the home screen.** Flat policy, no escalation (section 10 stays open).
4. **"Back to study" is NOT built.** No study app setting exists. If you want it, say so: it needs a single-app
   picker (new Blocks/Settings UI) and a `studyAppPackage` field in `userSettings`, which is a separate prompt.
5. **Mood for the pill uses the same 20/60/120/200 thresholds, applied to the session.** A 30-item session is
   already "Warming up". Say if session thresholds should be lower.
6. **Response log is behavioural data** (when the user chose to continue scrolling). Needs a line in the privacy
   statement / Play disclosure. Kept indefinitely like `scrollStats`.
7. Pill colours/sizes follow the design system tokens copied into `res`, so native and Flutter can drift. A comment
   points at `AppPalette` and a unit test pins the mood thresholds only.

## Edge cases that could break the flow, and what I do about each

**Counting (phase 1 hardening that phase 2 depends on)**
- Service killed by OEM battery manager mid-session: counts are persisted per count; engine state is rebuilt empty,
  so the next swipe starts a new session. Pill/card are views of the dead process and disappear with it.
- Process death between "Flutter wrote" and "native consumed": counts could be written twice. Window is milliseconds,
  documented; events use idempotent doc ids so they cannot double.
- Clock change / timezone travel / DST / midnight: day key and tz offset are taken per count; elapsed gaps use the
  monotonic clock, so a manual clock change cannot end or extend a session.
- App update changes view ids and detectors stop matching: counts stop (never wrong numbers). Island only shows after
  real counts, so it simply never appears. `adb logcat -s ScrollDamage` shows `NOT_SHORT_FORM` streaks for tuning.
- Auto-play ads between reels count as an item (they are a page). Documented, acceptable.
- TikTok Live / Inbox count (whole app treated as short-form, as the blocker already does).
- Comments panel scrolling in Reels may over-count: biggest known false-positive; you will report the number on device.
- Horizontal seek-bar scrubbing on YouTube: no page index change and no vertical delta, so `SAME_PAGE`.
- Split-screen / PiP / floating window: events from a non-active window fail the cheap `rootInActiveWindow` package
  check and are rejected.
- Screen turns off mid-swipe: burst timer fires with no valid window, rejected; a screen-off receiver also hides UI.
- Two accounts on one phone: unsynced counts and events are dropped when the uid changes (phase 1).
- Feature toggled rapidly: every toggle cancels timers, resets the engine and hides the pill and card.

**Island**
- No cutout, API < 28, corner/left/right punch hole, tall notch, double cutout, cutout on the bottom: handled by the
  geometry rules above, each a unit test with synthetic rects.
- Rotation, fold/unfold, display size / density / font scale change: recompute on `onConfigurationChanged`; hide in landscape.
- Status bar hidden / immersive: `y = 0` still valid; compact pill uses `max(statusBarHeight, cutout.bottom)`.
- `WindowManager.BadTokenException` or `addView` twice: single guarded holder, try/catch, a failed add disables the island
  for the session instead of crashing the service.
- Leaked window: removed in `hide()`, `onUnbind()`, `onInterrupt()`, and when the service instance changes.
- Notification shade pulled down / lock screen / overlay-hiding OEMs (MIUI etc.): shade covers it, lock screen hides it via
  screen-off rule; if an OEM suppresses accessibility overlays the pill is just invisible and counting still works.
- FLAG_SECURE apps and screen recording: pill may appear in recordings; harmless, no content.
- Animations disabled / reduce motion: no animation. TalkBack: pill hidden from accessibility, card announced once.
- Battery: no tree walks in the island path, updates are posted on the main looper and coalesced.

**Intervention**
- Offer appears while the user is mid-swipe: card is non-focusable and only the card area is touchable.
- Keyboard / dialogs / calls: card never takes focus; not shown during a focus session or block overlay; skipped when
  the window package is not a target app.
- Double tap on a button: first tap wins, card removed immediately, response logged once.
- Home action fails (screen pinning, some OEM lock): fall back to just dismissing; response still logged as `break`.
- User reopens the app right after "Take a break": new session, count restarts, next offer after N. (A cooldown or
  escalation would be a design change, deferred to your decision.)
- Offer fatigue: min 2 min between offers plus repeat every N items, so it cannot spam at a fast scroll rate.
- Feature off / accessibility revoked while the card is up: card removed in `setScrollDamageEnabled(false)` / `onUnbind`.
- Log growth: ring buffer of 200 rows; Flutter flushes on start/resume/ping; offline writes queue in Firestore.

## Files I expect to touch

New (Kotlin): `services/scroll/IslandGeometry.kt`, `ScrollMoodLevel.kt`, `IslandPolicy.kt`, `ScrollIsland.kt`,
`InterventionPolicy.kt`, `InterventionCard.kt`, `ScrollEventLog.kt`; tests for geometry, mood, island policy,
intervention policy, event log.
Edit (Kotlin): `StaylitAccessibilityService.kt` (hooks: counted, negative settle, window change, config change,
screen off, teardown), `ScrollDamageStore.kt` (event log persistence), `MainActivity.kt` (2 methods).
Resources: `res/drawable-nodpi/lit_scroll_pill.webp` (copy of `assets/images/lit_scroll.webp`), `res/values/colors.xml`
entries, `res/values/strings.xml` entries for the card copy.
New/edit (Dart): `scroll_event.dart`, `scroll_stats_repository.dart`, `native_service.dart`,
`scroll_damage_sync_provider.dart`; tests. `firestore.rules`.
No change: `AndroidManifest.xml`, `PermissionManager.kt`, `BlockOverlayActivity`, legacy services.

## Method / event contract (names must match exactly)

- `getPendingScrollEvents` -> `List<Map>` `{ts:int, day:String, tzOffsetMinutes:int, pkg:String, sessionCount:int, threshold:int, response:String}`
- `consumeScrollEvents` args `{events: List<Map>}` (same shape) -> `true`
- Existing `scroll_damage_update` ping also triggers the events flush.

## Security / privacy

- Stored/logged: counts, package ids of the four allow-listed apps, day keys, timestamps, response enum.
  Nothing from the screen. Island and card text are our own strings and the session count.
- No new permissions. Overlays are accessibility windows. Island/card never take input except the card buttons.
- Firestore owner-only. Response log is behavioural; privacy statement line needed (owner action).

## Acceptance

- `flutter analyze` clean, `flutter test` green, Kotlin compiles, Kotlin JVM tests pass (geometry, mood, island
  policy, intervention policy, event log).
- Phone with a centred camera hole: after 5 reels a black pill wraps the hole, left number counts up, right Lit.
- Phone/emulator with no cutout or a corner hole: compact pill under the status bar, never over the camera.
- Leaving Reels (feed, DMs, other app, home, screen off, rotate) hides the pill; turning the feature off hides it now.
- At 30 items the card appears once; Take a break goes Home; Keep scrolling re-offers after 30 more; each answer is a
  doc in `scrollEvents/{uid}/items`.
- Blocking, focus sessions, limits and the foreground notification behave as before.

## Checks I will run (never on your phone)

1. `flutter analyze`, 2. `dart format` on changed Dart files only, 3. `flutter test`,
4. `cd android && ./gradlew :app:compileDebugKotlin :app:testDebugUnitTest --offline -q`,
5. rules redeploy `firebase deploy --only firestore --project staylit-4064f` after tests are green.
Small commits on `feat/scroll-damage-native`, PR #42 description updated, no merge until you say.

## Manual device test steps (you run these)

Tip: you can test other cutout shapes without another phone: Settings -> Developer options -> **Display cutout**
(Corner / Double / Narrow / Tall / Wide), then reopen Reels each time.

1. Scroll 4 reels: no pill. 5th reel: pill appears around the camera, shows 5; keep going, number follows.
2. Mood: at 20 / 60 items the dot/colour steps up (use fast scrolling or lower the constant for a test build).
3. Feed / DMs / other tab inside Instagram: pill disappears within about a second.
4. Home button, recents, screen off, rotate to landscape: pill gone; back in Reels it returns after 5 new items.
5. Settings -> Display cutout -> Corner, then Wide, then None (if offered): pill never covers the camera or clock.
6. Feature Turn off from the Home card while the pill is up: pill disappears immediately; scrolling shows nothing.
7. At 30: card appears at the bottom. Tap Keep scrolling: gone; next card at 60. Tap Take a break: Home screen.
8. Ignore the card 12 s: it disappears and counts as `timeout`; Firestore `scrollEvents/<uid>/items/*` has rows.
9. Start a focus session with Instagram not blocked, scroll Reels: no pill or card during the session.
10. TalkBack on: the pill is silent, the card is announced once.
11. Force-stop Staylit and the accessibility service restart: no leftover pill, counting continues.
12. Regression: Shorts block, website block, limits, notification still work; "Staylit Protection Service" notification shown.

## Owner actions (what I cannot do)

- Approve or change the defaults in "Decisions needing your sign-off".
- Run the manual device tests above and send me the numbers (comments panel, Facebook, YouTube).
- Add the response-log line to the privacy statement / Play accessibility disclosure.
- Decide if "Back to study" should become its own prompt (study app picker).

## Rollback

All new code sits behind the existing `scrollDamageEnabled` flag (off by default). Remove the `scrollEvents` match and
redeploy to undo the rules. The island and card are additive windows; no existing file loses behaviour.
