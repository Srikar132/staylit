# Scroll damage phase 1: native counter + persistence + Flutter wiring (issue #41)

## Goal

Make the Home "Scroll damage" card show real numbers. The accessibility service counts how many
short-form items (Reels / Shorts / TikTok videos) the user pages through, per app, per session and per
local day. Counts survive process death, flow to Flutter over the existing event channel, and Flutter
stores them in `scrollStats/{uid}/days/{date}`. The card reads the last 7 days from there.

Out of scope: floating mascot overlay, break/redirect interventions (phases 2 and 3, need their own
prompt and design sign-off).

## Skills / docs read

- `AGENTS.md` (sections 2, 5, 7, 9, 10, 11, 13). Native service + rules + channel work is on the
  no-exceptions approval list. Enforcement stays in Kotlin. Keep the accessibility foreground service
  and its notification channel intact.
- GitHub issue #41 (proposed design, acceptance, risks).
- Skills I will lean on while building: `dart-add-unit-test`, `flutter-apply-architecture-best-practices`,
  `firebase-firestore`, `firebase-security-rules-auditor`, `dart-run-static-analysis`.

## Code inspected (and what it showed)

- `StaylitAccessibilityService.kt`
  - `serviceInfo` is built in code in `onServiceConnected` and already includes `TYPE_VIEW_SCROLLED`
    (`notificationTimeout = 100`, so same-type events are already throttled). No manifest or
    `accessibility_service_config.xml` change needed.
  - `onAccessibilityEvent` returns early in the `TYPE_WINDOW_STATE_CHANGED` branch (system package,
    limit exceeded). Scroll events skip that branch, so a counting hook placed right after
    `eventType` is read can never be skipped by it, and must never throw into the blocking logic.
  - `detectYouTubeShortsEnhanced()` / `detectInstagramReels()` do full tree walks (4 walks for YouTube).
    They are only run today after a 500 ms delay when a block is configured. Running them on every scroll
    event would be a battery problem, so the counter runs them **once per settled swipe and caches a
    positive result for 3 s** (see Design).
  - TikTok (`com.zhiliaoapp.musically`) has no detector: the blocker treats the whole app as short-form.
  - There is **no Facebook Reels detector** (`com.facebook.katana`); Facebook ids are obfuscated.
  - `onUnbind` is where handlers are removed and `instance = null`. The counter's handlers must be
    removed there too.
- `services/shared/BlockingConfig.kt`: SharedPreferences `blocking_config`. Not reused: scroll data gets
  its own prefs file (`scroll_damage`) so `clearAllConfigs()` cannot wipe counts.
- `MainActivity.kt`
  - `sendEventToFlutter` writes to `eventSink`, which exists **only while MainActivity's Flutter engine is
    listening**. When the Activity is dead and the service keeps counting, events go nowhere.
    `eventQueue` is keyed by event name, so it keeps only the last payload per name.
    => Events cannot be the source of truth. Native keeps the ledger; the event is only a "something
    changed" ping, and Flutter **pulls** the pending counts (also on app start/resume).
  - `handleMainMethodCall` is where new method names go. A name mismatch Dart<->Kotlin returns
    `notImplemented` silently, so the three method names are listed explicitly below.
- `lib/services/native_service.dart`: `focusEventStream` is a getter that calls
  `receiveBroadcastStream()` on every access. `FocusSessionNotifier` already uses it. A second listener
  would re-invoke native `onListen`, which replaces `eventSink`, and cancelling one would null it for the
  other. **I will make it one shared broadcast stream** (behavior-preserving change to this file).
- `lib/data/models/daily_stat.dart` (`dayKey`, `lastDays`), `daily_stats_repository.dart`,
  `daily_stats_provider.dart`, and `focus_session_repository.finishSession` (set-merge with
  `FieldValue.increment`, `tzOffsetMinutes`, `unawaited(...catchError)`): the pattern to copy.
- `focus_screen.dart` `_homeData()` already sets `scrollEnabled`; `scrollDamage` is never filled.
  `FocusHomeView` / `ScrollDamageCard` already render `ScrollDamageData` (count, mood, week bars, trend).
  No UI change is needed.
- `firestore.rules`: `dailyStats/{uid}/days/{date}` is owner-only read/write. New collection copies it.
- Kotlin unit tests already exist (`android/app/src/test/...`, JUnit 4.13.2 + `org.json` stub). New pure
  Kotlin gets JVM tests the same way.
- `test/presentation/screens/scroll_damage_test.dart` covers mood/card/sheet; not touched except if
  analyzer demands.

## Design

### 1. Counting (Kotlin, in the accessibility service)

New package `services/scroll/` (pure logic kept Android-free so it is JVM-testable):

| File | Pure? | Job |
|---|---|---|
| `ScrollCounterEngine.kt` | yes | debounce / swipe-settle state machine, session + day logic |
| `ScrollLedger.kt` | yes | pending per-day deltas: add, consume, JSON in/out |
| `ScrollTargets.kt` | yes | table: package -> how to confirm "short-form view is active" |
| `ScrollDamageStore.kt` | no | SharedPreferences `scroll_damage` (enabled, uid, ledger JSON), batching ping |

**What counts as one item.** One settled page change in a vertical pager:

1. Every `TYPE_VIEW_SCROLLED` from an allow-listed package (`com.instagram.android`,
   `com.google.android.youtube`, `com.zhiliaoapp.musically`, `com.facebook.katana`) is fed to the engine:
   only numbers (`fromIndex`, `toIndex`, `itemCount`, `scrollDeltaY` on API 28+). **No node, text, content
   description or view id is read on the per-event path.** A swipe is a burst of events; each event
   re-arms a 350 ms settle timer.
2. When the burst settles (350 ms quiet), the service asks the target's detector once whether the
   short-form view is active (YouTube -> `detectYouTubeShortsEnhanced`, Instagram -> `detectInstagramReels`,
   TikTok -> always true, Facebook -> new cheap "selected Reels tab" check, best effort). A positive answer is cached 3 s; a negative answer
   is not cached. Home feed / DMs / comments outside the active short-form view are rejected here.
3. The engine counts the swipe only if the page index differs from the last settled index
   (`fromIndex` baseline; if the app reports no index, fall back to cumulative `|scrollDeltaY| >= 200 px`),
   and at least 400 ms passed since the previous counted item (scroll jitter / bounce guard).
4. First settled swipe after entering an app sets the baseline and the index it moved from counts as the first change if it differs (so a normal first swipe counts).

**Session** = continuous short-form viewing; a new session starts when more than 60 s passed since the
last active settle. `sessions` for the day increments when a session starts. Per-session count lives in
engine memory (phase 2 needs it for mood/overlay; not shown in phase 1).

**Day rollover.** Day key is computed per counted item from the device's local time (`yyyy-MM-dd`,
identical to `DailyStat.dayKey`), with `tzOffsetMinutes` = the offset in minutes at that moment (same as
Dart `DateTime.timeZoneOffset.inMinutes`). Counts are written into the ledger under the day they happened,
so a session crossing midnight splits cleanly and nothing is lost if Flutter flushes late. Uses
`Calendar`/`TimeZone` (no `java.time`, minSdk safe).

**Enable flag.** `scrollDamageEnabled` is mirrored to native. While false, the hook returns after one
volatile read: no timers, no detectors, no counting. Turning it off cancels pending timers immediately.

### 2. Persistence and sync

- `ScrollDamageStore` keeps `{enabled, uid, pending: {day: {total, perApp{pkg:n}, sessions, tz}}}` in
  SharedPreferences `scroll_damage`. Written on every counted item (`apply()`, small JSON). Survives
  process/service death.
- **Ping:** the store notifies a static listener (`ScrollDamageNotifier`) at most once per 5 s after new
  counts. `MainActivity` registers the listener in `onListen`, clears it in `onCancel`/`onDestroy`, and
  sends `scroll_damage_update` `{day, total, perApp, sessionCount}` via `sendEventToFlutter`
  (informational; Flutter does not trust it as the data).
- **Pull + consume** (exactly-once-ish, no event-loss dependence):
  1. Flutter calls `getPendingScrollDamage` -> list of `{day, tzOffsetMinutes, total, perApp, sessions}`.
  2. Flutter writes each to Firestore (set-merge with increments, fire-and-forget; the offline queue makes
     it durable once enqueued).
  3. Flutter calls `consumeScrollDamage` with the same list; native **subtracts those amounts** (so counts
     that arrived in between are kept).
  A Dart-side in-flight guard serializes steps 1-3, so a ping and a resume cannot double-write.
- **Flutter triggers a flush** on: sync controller start, app resumed, `scroll_damage_update` ping, and
  right before sending `enabled=false`.
- **User switch:** `setScrollDamageEnabled(enabled, uid)` clears pending counts when `uid` differs from the
  stored uid, so one account's counts are never attributed to the next account on a shared device.

### 3. Firestore

Doc `scrollStats/{uid}/days/{yyyy-MM-dd}`:
`{date, tzOffsetMinutes, total, perApp: {<pkg>: n}, sessions, lastUpdated}`; written with
`SetOptions(merge: true)` and `FieldValue.increment`. `perApp` is a nested map (not dotted field paths),
so package names containing dots are fine.

Rules (`firestore.rules`), copy of the `dailyStats` rule:
```
match /scrollStats/{uid}/days/{date} {
  allow read, write: if isOwner(uid);
}
```
No schema validation in rules: same trade-off as `dailyStats` (the owner owns and self-reports their own
data). Deployed with `firebase deploy --only firestore` (this also re-publishes `firestore.indexes.json`
unchanged). No new index: the query is `orderBy(documentId) limit(7)`.

### 4. Flutter

- `NativeService`: shared event stream; add `setScrollDamageEnabled`, `getPendingScrollDamage`,
  `consumeScrollDamage`.
- `lib/data/models/scroll_day.dart`: `ScrollDay.fromMap`, `lastDays` (same shape as `DailyStat`).
- `lib/data/repositories/scroll_stats_repository.dart`: `streamRecent(uid, days)` and
  `addDeltas(uid, deltas)`; `lib/presentation/providers/scroll_damage_provider.dart`:
  `scrollDamageProvider(uid)` (`StreamProvider<ScrollDamageData>`).
- `lib/presentation/screens/focus/scroll_trend.dart`: pure `ScrollTrend.compare(today, yesterday)` ->
  text ("↓ 12% vs yesterday" / "↑ 8% vs yesterday" / "Same as yesterday" / null when yesterday is 0) and
  `good` (down = good).
- `lib/presentation/providers/scroll_damage_sync_provider.dart`: the controller that mirrors the setting +
  uid to native, runs the flush loop, and listens to the shared event stream + app lifecycle. Watched once
  from `HomeScreen` so it lives while logged in. No UI.
- `focus_screen.dart` `_homeData()`: when `scrollDamageEnabled`, watch `scrollDamageProvider` and pass the
  resulting `ScrollDamageData` (today count, 7 values oldest first, trend). Home card unchanged.

## Decisions and assumptions (flagging the ones you may want to change)

1. **Pull-based sync, event is only a ping.** Deviation from the issue's wording ("batched events carry the
   counts"): events are lost whenever the Activity is gone, which is exactly when the service counts.
   The event payload still carries `{day,total,perApp,sessionCount}` as the issue specifies.
2. **Shared event stream** in `NativeService` (see above) instead of a second `receiveBroadcastStream()`.
3. **Facebook Reels is best effort.** No existing detector and FB view ids are obfuscated; I will use a
   "selected tab text is Reels" check (reads node text transiently to compare, never stores or logs it).
   If it does not work on your device it is one table row to switch off.
4. **Index-based page change** from accessibility event numbers instead of reading screen content
   (privacy-safe), with the `|scrollDeltaY|` fallback. The 350 ms / 400 ms / 60 s / 3 s / 200 px constants
   are in one place and will need tuning on a real device.
5. **Trend compares today-so-far with full yesterday**, as the issue specifies, so it will look "down"
   most mornings. Easy to change to "same time yesterday" later (needs hourly data).
6. **No per-day cap or TTL** on `scrollStats`; history is kept indefinitely (feeds issue #37).
7. Counts are **approximate** (accessibility events differ by app version / OEM). UI already says
   "about"/"Collecting..."; no copy change.
8. Unit-test scope: engine + ledger (Kotlin JVM tests) and trend / ScrollDay / delta merge (Dart). The
   Kotlin tests run with `./gradlew :app:testDebugUnitTest --offline -q` (compile + JVM only, no device).

## Files I expect to touch

New (Kotlin): `services/scroll/ScrollCounterEngine.kt`, `ScrollLedger.kt`, `ScrollTargets.kt`,
`ScrollDamageStore.kt`; tests `src/test/kotlin/.../scroll/ScrollCounterEngineTest.kt`, `ScrollLedgerTest.kt`.

Edit (Kotlin): `services/StaylitAccessibilityService.kt` (hook, settle timer, detector adapter, Facebook
check, `onUnbind` cleanup, `setScrollDamageEnabled` entry point; foreground service/notification
untouched), `MainActivity.kt` (3 method cases, listener register/clear).

No change: `AndroidManifest.xml`, `accessibility_service_config.xml`, `PermissionManager.kt`, overlay code,
`BlockingConfig.kt`, any legacy file (`FocusModeManager`, `AppMonitoringService`).

New (Dart): `scroll_day.dart`, `scroll_stats_repository.dart`, `scroll_damage_provider.dart`,
`scroll_damage_sync_provider.dart`, `scroll_trend.dart`; tests under `test/data/...`, `test/presentation/...`.

Edit (Dart): `native_service.dart`, `focus_screen.dart`, `home_screen.dart` (one watch line),
`firestore.rules`.

## Method / event contract (names must match exactly)

Channel `com.staylit.app/native` (method):
- `setScrollDamageEnabled` args `{enabled: bool, uid: String}` -> `true`
- `getPendingScrollDamage` -> `List<Map>` each `{day: String, tzOffsetMinutes: int, total: int, perApp: Map<String,int>, sessions: int}`
- `consumeScrollDamage` args `{days: List<Map>}` (same shape as above) -> `true`

Channel `com.staylit.app/events`: event name `scroll_damage_update`, `data = {day, total, perApp, sessionCount}`.

## Security / privacy

- Stored/logged: counts, package ids of the four allow-listed apps, day keys, timestamps. Nothing else.
- Never read, store or log: node text, content descriptions, URLs, view ids, titles. The per-event path
  touches only event numbers. Detectors are the existing ones (they compare text transiently and log only
  fixed indicator strings); the Facebook check logs nothing from the screen.
- Logging (tag `ScrollDamage`) prints only outcome enums (`COUNTED`, `NOT_SHORT_FORM`, `SAME_PAGE`,
  `TOO_FAST`), package id and totals, so you can tune from `adb logcat -s ScrollDamage`.
- Firestore: owner-only, same as `dailyStats`. Counts are derived behaviour data: needs the privacy
  statement / Play accessibility disclosure already planned in the Turn on sheet; wording not changed here.
- Off by default; while off nothing is counted or sent. Existing pending counts at turn-off are flushed
  once, not discarded.
- Service must keep its foreground notification and channel. The counter adds no permissions.

## Acceptance

- `flutter analyze` clean, `flutter test` green (new tests included), Kotlin compiles
  (`./gradlew :app:compileDebugKotlin --offline -q`) and Kotlin unit tests pass.
- Setting off: no counting, no ping, `getPendingScrollDamage` returns what was already counted only.
- Setting on + accessibility on: scrolling 20 reels in Instagram shows about 18-22 on Home within seconds;
  home feed and DMs do not count; killing and reopening the app keeps today's total.
- Firestore doc `scrollStats/{uid}/days/{today}` appears and increments; 7-day bars and "down N% vs
  yesterday" render from it.
- Existing blocking (website, shorts, limits, focus) behaves unchanged.

## Checks I will run (never on your phone)

1. `flutter analyze`
2. `dart format` on changed Dart files only
3. `flutter test`
4. `cd android && ./gradlew :app:compileDebugKotlin --offline -q`
5. `cd android && ./gradlew :app:testDebugUnitTest --offline -q`
6. `firebase deploy --only firestore` after the rules diff is reviewed (once, after tests are green)

Git: branch `feat/scroll-damage-native`, small commits (engine+ledger+tests; store+service+channel;
dart data+sync; rules; home wiring), no `prompts/`, `designs/` or `.md` files, push, PR into `main`,
no merge until you say.

## Manual device test steps (you run these; I never install or launch the app)

Setup: build and install yourself (`flutter run` or your usual way), sign in, grant accessibility (and the
other permissions). Open Home. Use `adb logcat -s ScrollDamage` in a terminal for the tuning log.

1. **Off by default.** Home shows the slim "Scroll damage - Turn on" row. Scroll Instagram Reels 10 times:
   logcat shows nothing from `ScrollDamage`.
2. **Turn on.** Tap the card -> "Turn on". Card shows 0 / "Collecting...". Logcat does not need to show anything yet.
3. **Instagram.** Open Instagram -> Reels, swipe through exactly 20 reels at normal speed. Return to Staylit
   (Home). Count is 18-22 within a few seconds. Logcat shows ~20 `COUNTED` lines, few `SAME_PAGE`/`TOO_FAST`.
4. **Not counted.** In Instagram, scroll the home feed 15 times, scroll DMs, open comments on a reel and
   scroll them. Count must not move (logcat: `NOT_SHORT_FORM` for feed/DMs; comments are the case most likely
   to over-count, tell me the number).
5. **YouTube.** Open Shorts, swipe 20. Then open a normal video and scroll the recommendations: only the Shorts count.
6. **TikTok** (if installed) swipe 20; **Facebook Reels** (if installed) swipe 20 and tell me the number (best effort).
7. **Persistence.** With a non-zero count: swipe-kill Staylit from recents, scroll 5 more reels in Instagram
   (app dead), reopen Staylit: count includes the 5 within a few seconds of reopening.
8. **Day total after reboot of the process.** Force-stop Staylit from app settings, reopen: today's count unchanged.
9. **Firestore.** Console -> `scrollStats/<uid>/days/<today>` has `total`, `perApp`, `sessions`, `tzOffsetMinutes`.
10. **Week + trend.** After a second day of data (or edit yesterday's doc `total` in the console), the bars show
    both days and the trend chip reads "down/up N% vs yesterday".
11. **Turn off.** Card -> "Turn off". Scroll 10 reels: logcat silent, count unchanged.
12. **Blocking regression.** With a Shorts block configured, YouTube Shorts is still blocked/redirected as before;
    a focus session still blocks apps; website blocking still works; the "Staylit Protection Service"
    notification is still shown.
13. **Midnight** (optional): scroll just before and after 00:00 -> two day docs, no lost items.

## Rollback

All new native code sits behind the enabled flag. To disable without a revert, ship with the flag false
(it is by default). Rules addition is additive: removing the `scrollStats` match and redeploying is safe.
