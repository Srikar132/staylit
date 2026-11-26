# Lit-sheet block overlays + app-limit native sync

Two independent fixes. Both touch native Kotlin / platform channels, so both need sign-off (AGENTS.md section 2).

---

## Part A - App-limit and website block overlays use the Lit sheet

### Goal
The "app limit reached" and "website blocked" screens still use the old `SimpleBlockOverlay` (XML, black background, green icon, hard-coded hex, "dialog_holo" frames, auto-dismiss bar). The short-form block already uses the Lit sheet (`LitSheet` + `LitSheetSpec`): Warm Focus tokens, Space Grotesk, Lit mascot, one orange pill, light/dark follows the app Appearance. Make the two remaining blocks look the same.

### Code inspected
- `services/overlay/SimpleBlockOverlay.kt` + `res/layout/overlay_block_shorts.xml`, `overlay_block_website.xml` (old look, `TYPE_APPLICATION_OVERLAY`)
- `services/scroll/LitSheet.kt`, `LitSheetSpec.kt`, `ScrollDamageUi.kt` (owns the one `LitSheet`, `showBlocked`/`showTimesUp`)
- `StaylitAccessibilityService.kt`: `showAppLimitExceededOverlay` (~2031), `showWebsiteBlockOverlay` (~1584), `showBrowserShortsBlockOverlay` (~1613), shorts call sites that already do `scrollUi?.showBlocked(...) != true -> SimpleBlockOverlay` fallback
- `services/web/WebBlockingVPNService.kt:574` (`showWebsiteBlockedOverlay`, not an AccessibilityService)
- Flutter overlays (`presentation/overlays/screens/*`, shown through `OverlayLauncher`/`BlockOverlayActivity`) already use the shared design widgets (`OverlayBackground`, `LitBadge`, `BlockHeader`, `BlockActions`). **Not touched.**

### Findings
- Which overlay shows which block: app limit -> `enforceAppLimit` does BACK x3 + HOME, then `showAppLimitExceededOverlay` -> `SimpleBlockOverlay` (so the sheet is informational; the user is already on the launcher). Website (accessibility URL hit) -> `SimpleBlockOverlay.showWebsite`. Website (VPN hit) -> same, from the VPN service.
- `LitSheet` needs an `AccessibilityService` (window type `TYPE_ACCESSIBILITY_OVERLAY`), so the VPN service cannot own one.

### Decisions (veto any)
1. Add two modes: `SheetMode.LIMIT`, `SheetMode.WEBSITE`, and two specs in `LitSheetSpec` (pure, unit tested):
   - `limitReached(appLabel, limitMinutes)`: title "$appLabel limit reached", body "You used it for $limitMinutes min today. It opens again tomorrow.", primary "Got it", no chips, no hint.
   - `websiteBlocked(domain, focusActive)`: title "$domain is blocked", body "You asked Lit to keep you off it." (focus session: "Blocked during your focus session."), primary "Got it".
   - Both `modal = true`. No break passes: passes belong to short-form only.
2. `ScrollDamageUi` gets `showLimitReached(...)` and `showWebsiteBlocked(...)` reusing its single sheet and arbitration. These two sheets do not auto-dismiss on window change (the VPN path has no reliable package); the user taps "Got it".
3. The 3 accessibility call sites use the sheet first and fall back to `SimpleBlockOverlay` only if the sheet could not be shown (same pattern as shorts).
4. `WebBlockingVPNService` asks the running `StaylitAccessibilityService` instance to show the sheet; falls back to `SimpleBlockOverlay` if the accessibility service is not running.
5. Lit image: reuse `lit_focused_sheet`. No new assets.
6. `SimpleBlockOverlay` and its XML stay (still the fallback). Delete later once you confirm the fallback never fires.

### Files expected to touch
`LitSheetSpec.kt`, `ScrollDamageUi.kt`, `StaylitAccessibilityService.kt`, `WebBlockingVPNService.kt`, tests in `android/app/src/test/kotlin/.../scroll/` (spec copy + rules).

---

## Part B - "Limit shows ON but is not enforced until I toggle off/on"

### This is GitHub issue #15
Same root cause as `[P0] App limits: native state is in-memory only and lost on process death` (#15). Part B fixes the issue's whole proposal, plus the Dart side the issue does not mention (nothing pushes limits on login). Mapping:

| #15 item | In this prompt |
|---|---|
| Persist limits natively, single store, load on service start/boot | B3 (SharedPreferences in `StaylitNativeLimitsHolder`; loaded in `onServiceConnected`. The system restarts the accessibility service after reboot, so no boot receiver is needed) |
| Channel call explicit full-replace; remove single-package helpers | B5: `updateLimits` stays full-replace and is documented as such on both sides; `AppLimitNativeService.setAppLimit/setAppLimits/removeAppLimit` removed (zero callers confirmed in `lib/`; they would wipe every other limit) |
| Delete unused `app_limits_map` read | B6: removed from `AppLimitMonitoringService.updateLimitsCache` (nothing writes it; the cache is already always empty, so behavior is unchanged) |
| Sync limits in `appBootstrapProvider` | B1: the sync provider runs as soon as the home shell shows, which is the first moment a signed-in user exists, and also covers login/logout/resume. Bootstrap itself stays untouched |
| `AppLimitManager` writes a different prefs store (`app_limits`) | Left alone: it is the legacy-but-live `FocusModeManager` path (AGENTS.md section 7). Needs its own trace-every-caller prompt before unifying |

### Your guess vs the code
- Right that it is a sync problem. Not quite right on where: it is **not** the Focus screen that pushes limits.
- Native keeps limits only in memory: `StaylitNativeLimitsHolder.dailyLimits` is a `ConcurrentHashMap`, no persistence. Firestore (the UI) is the only durable copy.
- The only place Flutter pushes limits to native on its own is `BlocksScreen.initState` -> `_syncLimitsToNative()`:
  1. The Blocks tab is lazily built (`home_screen.dart`), so if the user never opens it, nothing is pushed.
  2. Even when opened, it does `ref.read(appLimitsProvider(uid)).whenData(...)` right after the first frame. At that moment the Firestore stream is usually still loading, so `whenData` does nothing and nothing is pushed.
- Toggling off -> on works because `_AppLimitTile._handleToggle` pushes after the stream is loaded.
- Consequences: new login / new device / reinstall / reboot / app swiped away (accessibility service restarts with an empty holder) -> UI says ON, native has no limit. Logging out also never clears native limits, so another account's limits can leak.

### Fix
Dart (no UI):
1. New `lib/presentation/providers/app_limit_sync_provider.dart`, watched once in `HomeScreen` next to `scrollDamageSyncProvider`:
   - listens to `appLimitsProvider(uid)`; on every **data** event pushes `{package: dailyLimit}` of active limits via `AppLimitNativeService.updateLimits` (skips loading/error)
   - pushes `{}` when the user is signed out (not just loading)
   - re-pushes the last known map on app resume
   - the pure "limits -> map" function is unit tested
2. Remove the unreliable `_syncLimitsToNative()` call from `BlocksScreen.initState` (keep the post-edit pushes in the tiles: instant feedback).

Kotlin (so enforcement survives restart without opening the app):
3. `StaylitNativeLimitsHolder` persists to SharedPreferences (`app_limits_native`, JSON) on every `updateLimits`/clear, and loads on first use (`init(context)` from `StaylitAccessibilityService.onServiceConnected` and the `updateLimits` channel handler). Encode/decode is a pure function, JVM tested.
4. Signed-out `updateLimits({})` clears the persisted copy too.
5. Remove `AppLimitNativeService.setAppLimit`, `setAppLimits`, `removeAppLimit` (no callers). Doc comment on `updateLimits` (Dart) and on the Kotlin holder: "full replace, not merge".
6. Delete the dead `app_limits_map` read in `AppLimitMonitoringService.updateLimitsCache`.

### Files expected to touch
`app_limit_sync_provider.dart` (new), `home_screen.dart`, `blocks_screen.dart`, `StaylitNativeLimitsHolder.kt`, `StaylitAccessibilityService.kt` (init call), `MainActivity.kt` (init call only; the channel method name `updateLimits` is unchanged), tests.

---

## Security / privacy
No new data leaves the device. Persisted limits are package names + minutes in app-private prefs. No Firestore rules change, no manifest change, no new permission, no channel method renamed.

## Risks
- Sheet shown from the VPN path depends on the accessibility service; fallback covers it.
- Persisted limits could outlive a logout if the sign-out push never runs (app killed in the same instant); next launch overwrites them.
- Part A and B are independent; either can be reverted alone.

## Acceptance criteria
A. App limit exceeded -> Lit sheet (Lit, title, one orange pill), same look as the shorts block, correct in light and dark. Website blocked (browser and VPN path) -> same sheet. "Got it" dismisses. Focus session: website body says so. Fallback overlay only when accessibility is off.
B. 1. Turn a limit on, force-stop the app, reboot the phone, do NOT open Staylit: the limit still enforces. 2. Log in on a fresh install with limits in Firestore: after the first Focus screen load the limit enforces without visiting Blocks. 3. Log out: native limits are cleared (`adb logcat` shows `Updated 0 app limits`). 4. Toggle off/on still works.

## Checks
- `flutter analyze`, `dart format` (changed files only), `flutter test`
- Kotlin JVM tests: `cd android && ./gradlew testDebugUnitTest` (the existing scroll tests run there)
- Native behavior: manual on a real device (you run it; I will not install or launch the app)

## Manual test steps
1. Settings: accessibility + overlay permissions on. Set a 1-minute limit on an app, use it past the limit: Lit sheet "limit reached", app already sent home.
2. Open a blocked website in Chrome: Lit sheet "$domain is blocked". Repeat with the VPN blocking on and accessibility off: old fallback shows.
3. Start a focus session, open a blocked site: body says "Blocked during your focus session."
4. Part B steps 1-4 above.
5. Switch Appearance to Dark in Staylit, trigger each sheet again.

## Owner todos after build
Run the manual steps on a device; confirm the fallback overlay never shows, then tell me to delete `SimpleBlockOverlay` + its two layouts.
