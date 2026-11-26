# Offline-first caching fixes (stop needless reloads)

## Goal
Stop the "data refetching / loading flash" when opening the focus settings sheet, Blocks tab, app picker and Groups. Firestore persistence is already on (`lib/main.dart:70`), so this is **Dart-side provider/stream hygiene only**. No new local DB.

## Skills read
`flutter-apply-architecture-best-practices`, `dart-fix-runtime-errors`, `dart-add-unit-test` (guidance only).

## Code inspected
- `lib/main.dart` (persistence on, unlimited cache)
- `lib/presentation/screens/home_screen.dart` (IndexedStack, tabs built once)
- `lib/presentation/providers/{settings,group,blocked_content,app_management_provide,session_history,usage_stats,auth}_provider.dart`
- `lib/data/repositories/{settings,group}_repository.dart`
- `lib/models/focus_time_bottom_model.dart`, `lib/models/block_app_bottom_model.dart`
- `lib/presentation/screens/{blocks,group,progress,focus}_screen.dart`

## Findings -> fixes

| # | Problem | Fix |
|---|---|---|
| 1 | `focus_time_bottom_model.dart:287` `ref.invalidate(userSettingsProvider)` after every edit tears down the realtime stream -> loading flash | Remove the invalidate. Stream already pushes the write (local writes fire snapshots immediately). |
| 2 | `settings_repository.dart:17` `includeMetadataChanges: true` -> 2 emissions (cache + server), 2 rebuilds | Drop the flag. Cache-first emit is kept. Also remove the redundant in-memory `_cachedSettings` + unused `cachedSettingsProvider` / `ensureSettingsProvider` (verify zero callers first; grep showed none outside the provider file). |
| 3 | `focus_time_bottom_model.dart:248` falls back to defaults (25/0/...) when stream not ready and sets `_isInitialized = true`, so real values never load | Only mark initialized once real settings arrive; show existing loading UI until then. Keep defaults only for the error / no-user case. |
| 4 | `installedAppsProvider` is `autoDispose` -> native package scan re-runs every time a sheet opens | Make it keep-alive (plain `FutureProvider`). Invalidate on app resume so installs/uninstalls are picked up (simple `WidgetsBindingObserver` in `home_screen.dart`, or invalidate when the Blocks picker opens only if cache older than N min - pick the observer, less code). |
| 5 | `blocks_screen.dart:2043` `_AppSelectionDialog` calls `InstalledApps.getInstalledApps(true, true)` (with icons, heavy) in `initState` every open | Add a keep-alive `FutureProvider<List<AppInfo>>` wrapping that call (in `app_management_provide.dart`), watch it in the dialog, drop the local `_installedApps/_isLoading` state. Same app-resume invalidation as #4. |
| 6 | `group_provider.dart:33` `groupSearchProvider(query)` = one new never-disposed live listener per search string, over all public groups | Make it `autoDispose` so listeners die when the search closes. Keep behavior otherwise. (Server-side prefix query is a larger change - out of scope.) |
| 7 | `currentUserProvider` (`auth_provider.dart:64`) emits `null` while auth is loading -> "Please login first" flash in sheet, spinner in Progress | While `authState` is loading, return a stream that does not emit (never completes) so the provider stays `AsyncLoading` instead of fake-null. Callers already handle `.value == null`; verify router/auth gates (`shouldShowHomeProvider` etc.) do not depend on the loading->null emit. **Highest regression risk - check every `currentUserProvider` consumer.** |
| 8 | `todayUsageStatsProvider` never refreshes except Progress pull-to-refresh -> stale chip on Focus | Invalidate it when the Focus or Progress tab becomes selected and on app resume. `AsyncValue` keeps previous value, so no spinner flash. |

## Explicitly NOT changing
- Native Kotlin, manifest, platform channels, `firestore.rules` (none needed).
- `_AppLimitTile._loadUsage` per-tile native call and `nativePersistent*` providers: cheap, only used inside derived providers; leave alone.
- Group search server-side querying, Drift/outbox (#31), any new local DB.

## Files expected to touch
- `lib/models/focus_time_bottom_model.dart`
- `lib/data/repositories/settings_repository.dart`
- `lib/presentation/providers/{settings_provider,app_management_provide,group_provider,auth_provider}.dart`
- `lib/presentation/screens/{blocks_screen,home_screen}.dart`
- Test: `test/...` for settings repo/provider behavior if feasible without Firebase (fake stream); otherwise none.

## Requirements
- No raw hex / `Colors.*` (architecture test).
- No behavior change to blocking enforcement.
- Keep screen/view split.

## Security / privacy
No new data stored or sent. No rule changes. Keep-alive caches hold only installed-app list/icons in memory (already in memory today while sheet is open).

## Acceptance criteria
1. Open focus settings sheet repeatedly: no spinner after first load; values shown are real, never the 25/0 defaults.
2. Change duration / breaks / toggles: UI updates with no flash; value persists after kill + reopen (also in airplane mode).
3. Open "Block apps" sheet and Blocks app picker a 2nd time: list appears instantly (no native rescan) within a session.
4. Install/uninstall an app, return to Staylit: lists reflect it.
5. Groups tab: switching tabs causes no reload; closing search stops its listener.
6. Cold start: no "Please login first" flash; no wrong-user/null flicker; sign-out still returns to login.
7. Focus tab phone-usage chip updates when returning to the tab.

## Checks
- `flutter analyze`
- `dart format` on **changed files only** (never `dart format lib`)
- `flutter test`

## Manual test steps (user runs the app - I will not install/launch)
1. Fresh launch, wait for Focus tab. Open the focus-time sheet, close, reopen x3: no spinner.
2. Change duration to 45, close; reopen: 45. Force-stop app, airplane mode, relaunch, reopen: still 45.
3. Blocks tab -> open app picker, close, reopen: instant.
4. Home -> Groups -> Blocks -> Groups: no loading state on return.
5. Groups -> search "a", type more, close search; no growth in listeners (check `flutter run` logs / DevTools if wanted).
6. Sign out, sign in: normal flow, no flash of "Please login first" on cold start.
7. Use another app for a minute, return: Focus phone-usage chip updated.

## Owner todos after build
- Run the manual steps above on device (device behavior can't be unit tested).
- Decide later whether Drift is wanted for ML usage time-series (separate prompt).
