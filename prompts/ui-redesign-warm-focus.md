# UI redesign: "Warm Focus" design system + production theming (System / Light / Dark)

## Goal

1. Build a proper, production-grade **theming feature**: Light, Dark and **System (default)**, persisted
   on the device, applied before the first frame (no flash), reflected in the overlay engine, with a
   user-facing Appearance setting.
2. Re-skin the whole app to `designs/design-system.md` / `designs/reference-focus-ui.png` (cream canvas,
   burnt-orange accent, near-black emphasis surfaces, big rounded shapes, scalloped edges, ring timer,
   hatched-peak bar charts, black bottom nav) in both light and dark.

Behavior, providers, routing, platform channels and native code do not change, except the small items under
"Non-visual changes".

## Skills / files read

- Read: `AGENTS.md` (sections 2, 3, 6, 11), `designs/design-system.md`, `designs/reference-focus-ui.png`.
- Read: `lib/core/theme/app_theme.dart` (full: `AppTheme.darkTheme` + `AppColors`), `lib/main.dart`
  (`themeMode: ThemeMode.dark`, fixed system-UI style in `main()` and `overlayMain()`),
  `lib/presentation/overlays/overlay_app.dart` (`theme: AppTheme.darkTheme`, fixed light status icons),
  `lib/presentation/screens/home_screen.dart`, `lib/core/router/app_router.dart`,
  `lib/data/models/user_settings_model.dart` (has an unused `theme` string, default `'dark'`),
  `lib/core/constants/images.dart`, `pubspec.yaml` (no `shared_preferences`, no custom font),
  `BlockOverlayActivity.configureFlutterEngine` (calls `super`, so plugins are registered on the overlay engine;
  verify at build time).
- Measured: **459** `AppColors.*` references and **103** raw `Colors.(white|black|grey|blue|...)` uses across
  about **40 files**; only 1 raw `Color(0x...)` left outside the theme file (earlier `theme-consistency-audit`
  work). So the app is token-driven but the tokens are static dark constants: they cannot react to a theme mode.
- Skills to use at build time (not read yet): `flutter-apply-architecture-best-practices`,
  `flutter-add-widget-test`, `dart-add-unit-test`, `flutter-fix-layout-issues`, `dart-run-static-analysis`,
  `ui-ux-pro-max` (contrast / accessibility).

## Decisions (confirmed with user)

1. **Theme default = System**, with explicit Light / Dark override. Implemented as a real feature (below), not a flag.
2. **Phased rollout** on an integration branch (see Release strategy).
3. **Illustrations: user supplies art.** Optional illustration slot; ship without art.
4. **Font: Plus Jakarta Sans**, bundled as assets (no runtime fetch).
5. Professional coding standard throughout (see "Engineering standards").

## Architecture of the theming feature

Layering follows the existing project layout (`core/`, `data/repositories`, `presentation/providers`), no new
architecture pattern.

```
lib/core/theme/
  app_palette.dart      ThemeExtension<AppPalette>: every color token, light + dark instances, copyWith, lerp
  app_dimens.dart       AppSpacing / AppRadius / AppSizes (mode-independent static consts)
  app_typography.dart   TextTheme builder (font family, scale, tabular figures)
  app_theme.dart        AppTheme.light / AppTheme.dark, both built by ONE private _build(palette, brightness)
  theme_context.dart    extension on BuildContext { AppPalette get palette; }
lib/data/repositories/
  theme_repository.dart abstract interface class ThemeRepository + SharedPreferencesThemeRepository
lib/presentation/providers/
  theme_mode_provider.dart  initialThemeModeProvider, themeRepositoryProvider, ThemeModeNotifier
lib/presentation/widgets/
  appearance_sheet.dart  System / Light / Dark selector (bottom sheet, existing pattern)
```

Rules the design follows (how production Flutter apps do it):

- **One theme builder.** `AppTheme.light` and `AppTheme.dark` come from the same `_build(palette, brightness)`, so
  component themes can never drift between modes.
- **Colors are a `ThemeExtension`** (`AppPalette`), read with `context.palette`; `ColorScheme` is populated from the
  same palette so Material widgets and custom widgets agree. Mode-independent values (spacing, radii, sizes) are
  plain `const` classes, not extension fields.
- **`ThemeMode` is Flutter's own enum.** Persist `ThemeMode.name`; parse with a safe fallback to `ThemeMode.system`
  (unknown/legacy/corrupt value never crashes).
- **Persistence is device-local, not Firestore.** Theme is a device preference and must apply before login and
  before the first frame. Stored with `SharedPreferencesAsync` under key `theme_mode`.
- **No flash on cold start.** `main()` awaits `repository.load()` before `runApp` and injects the value through
  `ProviderScope(overrides: [initialThemeModeProvider.overrideWithValue(mode)])`. `ThemeModeNotifier.build()`
  returns it synchronously.
- **Notifier updates state first, then persists** (optimistic); a failed write is logged and state is kept; the
  next launch falls back to the last good value.
- **System bars follow the resolved brightness**, from `Theme.of(context).brightness` in the `MaterialApp.builder`
  via `AnnotatedRegion<SystemUiOverlayStyle>` (edge-to-edge, transparent bars, icon brightness inverted per mode).
  The fixed styles in `main()` and `overlayMain()` are removed.
- **Overlay engine follows the same setting.** `SharedPreferencesAsync` reads the platform store directly (no
  per-isolate cache), so `overlayMain()` calls the same repository, injects the same provider override, and
  `OverlayApp` sets `theme`, `darkTheme`, `themeMode`. No Kotlin change, no shared Riverpod state. If the plugin turns
  out not to be registered on the overlay engine, fall back to `ThemeMode.system` and raise it before touching
  native code (that would need approval).
- **UI**: an "Appearance" row in the profile screen opens `AppearanceSheet` (`SegmentedButton<ThemeMode>` with
  System / Light / Dark, icons + text labels, helper text "System follows your phone's setting"). Selecting applies
  immediately (MaterialApp animates the theme change).
- `UserSettingsModel.theme` (Firestore, unused, default `'dark'`) is no longer read. It is removed from the model in
  the cleanup phase; old docs that still contain the field are unaffected.

## Engineering standards (apply to every phase)

- Null-safe, `const` constructors, `final` fields, immutable models, no `dynamic`, no `!` without a proof comment.
- Small single-purpose widgets (<= ~150 lines each); no business logic in `build`; screens compose shared components.
- All colors via `context.palette`, all text via `Theme.of(context).textTheme`, all spacing/radii via
  `AppSpacing`/`AppRadius`. No inline hex, no raw `Colors.*` except a documented, palette-provided
  `onScrim` for text over photos/overlays.
- Repository behind an interface; providers receive dependencies (no `X.instance` inside new classes), so everything
  new is unit-testable with fakes.
- Accessibility: `Semantics` labels on icon-only buttons, touch targets >= 48 px, contrast >= 4.5:1 body / 3:1 large
  text and icons (enforced by a test, below), no layout breakage at text scale 1.3 or in short windows.
- Painters (`ScallopedEdge`, charts, ring) are `const`-constructible with correct `shouldRepaint`, no per-frame
  allocation. No `BackdropFilter`. Keep lazy `IndexedStack` tabs.
- `dart format`, `flutter analyze` clean, no new lints suppressed. Public theme APIs get `///` docs.
- Commits small and scoped (one concern each), Conventional Commit messages.

## Release strategy (important)

Work happens on an integration branch `feat/warm-focus-ui`; every phase is a PR into it. `main` / any release
receives it only after **Phase 2** at the earliest. Reason: until the token sweep is done, unmigrated screens
would show dark constants on a cream canvas whenever the phone is in light mode, and System-default would expose
that to real users.

## Phases

| Phase | Scope | Result |
|---|---|---|
| 1 | Foundation + theming feature: palette, light/dark `ThemeData`, font, persisted `ThemeMode` (System default), Appearance sheet, system-bar handling, overlay wiring (providers only), tests, debug gallery | Theme switching works end to end; most screens still old-looking |
| 2 | **Token sweep** (mechanical, behavior-neutral): migrate all 459 `AppColors` refs and 103 raw `Colors.*` uses to `context.palette`, delete `AppColors`, route overlays through the palette | **Whole app correct in light and dark**, old layouts. First releasable checkpoint |
| 3 | Shared components + the 3 reference screens: bottom nav, welcome, Focus tab (home), active focus session | Reference look on the main flow |
| 4 | Remaining screens/sheets/dialogs/onboarding/overlays restyled; native splash + launcher day/night; remove dead `theme` field; update `AGENTS.md`; guard tests | Done |

### Phase 1 files

- New: `app_palette.dart`, `app_dimens.dart`, `app_typography.dart`, `theme_context.dart`, `theme_repository.dart`,
  `theme_mode_provider.dart`, `appearance_sheet.dart`, `assets/fonts/PlusJakartaSans-*.ttf` (400/500/600/700/800,
  OFL license file included), debug-only `design_gallery_screen.dart` (compiled out of release).
- Edit: `app_theme.dart` (single `_build`, `AppTheme.light` + `AppTheme.dark`; `AppColors` kept as-is until
  Phase 2 so nothing breaks), `main.dart` (load persisted mode, override provider, `theme`/`darkTheme`/`themeMode`,
  `AnnotatedRegion` in builder, remove fixed system UI style), `overlay_app.dart` + `overlayMain()` (same wiring),
  `profile_screen.dart` (one Appearance row), `pubspec.yaml` (`shared_preferences`, font assets).
- Component themes covered by `_build`: button, outlined/text button, card, chip, input, dialog, bottom sheet,
  switch, slider, progress, snackbar, list tile, badge, app bar, navigation bar, FAB, divider.
- Palette as built: canvas, surface, surfaceRaised, surfaceTrack, border, divider, accent, accentSoft,
  accentStrong, accentText (accent for text/icons on canvas, darker so it passes contrast), onAccent, ink,
  onInk, onCanvas / onCanvasSecondary / onCanvasMuted / onCanvasDisabled, chartAlt, badge,
  success / warning / error / info, onError, scrim, onScrim, premium, `categorical` + `groupColor(name)`.
  Note: raw `accent` (E8653A) on cream is only 2.8:1, so orange text on canvas must use `accentText`.

### Phase 2 mapping (old -> new)

| Old (`AppColors`) | New (`palette`) |
|---|---|
| background | canvas |
| surface / surfaceElevated | surface / surfaceRaised |
| textPrimary / textSecondary / textMuted / textDisabled | onCanvas / onCanvasSecondary / onCanvasMuted / onCanvasDisabled |
| border / divider | border / divider |
| accent / accentHighlight / accentMuted | accent / accentStrong / onCanvasMuted |
| buttonFill | accent (fill) with onAccent (text) |
| error / success / warning / info | same names |
| activeIndicator / premium | accent / premium |
| `avatarColors`, `groupColor(name)` | `palette.categorical`, `palette.groupColor(name)` (mode-aware) |

Raw `Colors.white*`/`black*`/`grey*`: map by role (text on canvas, text on accent, scrim text). Anything over a
photo or gradient uses `palette.onScrim`. Each of the 40 files is migrated in its own small commit.

### Phase 3 and 4 file lists

Same screen inventory and notes as the earlier version of this prompt: `focus_screen.dart` (greeting, Today's
Goal card, Today's sessions, one CTA), `active_focus_screen.dart` (ring timer, message card, control dock wired to
existing handlers, scroll preserved for short windows), `welcome_screen.dart` + splash, `home_screen.dart` (black
bottom nav, same 5 destinations and lazy tabs), then `blocks_screen.dart` (2556 lines), insights, usage stats,
groups (3 screens), profile, permissions (restyle only, no logic), app limits (`app_limits_screen.dart` is
unrouted WIP: ask first), save session, onboarding (4), bottom sheets/dialogs (focus time, block apps, audio, end
session, auth actions, allowed apps drawer, parental control dialogs), Lumo screen/mascot (restyle only), and the
4 block overlays.

## Assumptions (reply "no" and name the item to change)

- A1. `shared_preferences` is added as a **key-value store only** (theme mode). It is not a database; the Drift +
  outbox work (#31) stays separate. This does touch AGENTS.md's "no local DB dependency without discussion" rule,
  so **adding the dependency needs your explicit OK** (the Yes below covers it).
- A2. Theme mode is **not synced** across devices (new device starts at System).
- A3. Dark is derived from the Warm Focus tokens (warm near-black canvas, same orange accent, cream text); the old
  Obsidian/Silver look is retired in Phase 2 when `AppColors` is deleted.
- A4. Keep the 5 existing nav destinations in the black bar (reference shows 4).
- A5. "Your Subject" has no data model; Phase 3 shows "Today's sessions" (data already streamed) in that style.
- A6. Charts are `CustomPaint`; no new chart dependency. Icons: Material rounded/outlined; no icon package.
- A7. Photo backgrounds (`backgroundImageProvider`) are not part of this design: the Focus tab and active session use
  the flat canvas; selector code is left until you decide to delete it (Phase 4).
- A8. Splash/launcher colors move to day/night variants in Phase 4 (`flutter_native_splash` supports dark colors);
  this regenerates Android resources but changes no Kotlin or manifest logic.

## Non-visual changes (the only logic touched)

1. Theme persistence + provider (new, above).
2. Phase 3: `userSettings.dailyGoalMinutes` (int, default 120, absent = 120) and a read-only stream of the last
   7 days from `dailyStats/{uid}/days` for the goal card. No rules change.

Dependency warning: the chart reads `dailyStats.totalFocusTime` (minutes). Manually saved sessions never write it
(GitHub #14) and the user doc total has a unit mismatch (#16). Fix #14 before Phase 3 or the chart undercounts.

## Security / privacy

- Theme preference is stored locally only, contains no personal data, and is not sent anywhere.
- Fonts and illustrations are local assets; no remote fetch.
- No permissions, manifest, Firestore rules, platform-channel or Kotlin changes in Phases 1-3. If the overlay
  plugin check fails (see above) native work would be a separate approval.
- `designs/reference-focus-ui.png` is a third-party mockup in a public repo: confirm you may publish it, or
  move/ignore `designs/`.

## Acceptance criteria

- Phase 1: fresh install follows the phone's mode; choosing Light/Dark/System in Appearance applies instantly and
  survives app restart; no wrong-theme flash on cold start; status/nav bar icons readable in both modes; the block
  overlay uses the same mode; all tests green.
- Phase 2: every screen/sheet/dialog/overlay is legible and on-palette in both modes; zero `AppColors` and zero raw
  `Colors.white/black/grey/...` (except `onScrim` sites); behavior unchanged.
- Phase 3: the three reference screens match the mockup (layout, tokens, radii, type scale) in light and dark;
  session start/pause/resume/stop/save flow unchanged; works in split-screen and at text scale 1.3.
- Phase 4: all screens restyled; day/night splash; `AGENTS.md` section 3 (dark-only, `darkTheme`, no light theme)
  and the Hive/local-storage note updated; `UserSettingsModel.theme` removed.

## Checks to run

- `dart format .`, `flutter analyze` after every phase; `flutter test`.
- Unit tests (`dart-add-unit-test`): `SharedPreferencesThemeRepository` (round trip, unknown value -> system,
  write failure), `ThemeModeNotifier` (initial value, set, persists, failure keeps state), `AppPalette`
  (`copyWith`, `lerp` endpoints and midpoint, `light`/`dark` have identical token sets).
- **Contrast test**: WCAG contrast function; assert every (on-X, X) token pair in both palettes meets 4.5:1 (body) or
  3:1 (large/icons). Fails the build if a token change breaks readability.
- Widget tests (`flutter-add-widget-test`): app switches `Theme.of(context).brightness` when the notifier changes;
  `AppearanceSheet` selection; `DurationText`, `BarChart` (peak, empty data), `FocusRingTimer` (0/50/100%),
  `ScallopedEdge` (tiny widths).
- **Architecture guard test** (`test/architecture/`): scans `lib/` and fails if `Color(0x`, `Colors.white|black|grey`
  or `AppColors` appear outside `app_palette.dart` and the documented allow-list. Added in Phase 2, tightened in 4.
- Manual device checks below (no CI exists).

## Manual test steps (device or emulator)

1. Phase 1: set the phone to light, fresh install -> app is light; switch phone to dark while running -> app
   follows (System). In Appearance choose Dark, force-stop, relaunch -> still dark, no flash. Choose Light -> same.
2. Trigger a block overlay (limit/shorts/website) in each mode and confirm it matches the app's mode, including
   after changing the mode and triggering again without restarting the app.
3. Rotate the font scale to 1.3 and open the gallery in both modes: no overflow, contrast readable.
4. Phase 2: walk every tab, sheet, dialog, onboarding and permission screen in both modes; confirm no
   dark-on-dark or light-on-light text and no invisible icons.
5. Phase 3: cold start -> welcome -> home; start a focus session, pause/resume, Ambient, Stop -> save flow; repeat in
   split-screen and a floating window; repeat in airplane mode (UI must still render).
6. Phase 4: fresh install, check the native splash in both modes; an existing install keeps working.

## Risks and open questions

- Largest risk is the Phase 2 sweep size and `blocks_screen.dart` (2556 lines): one small commit per file, review by
  diff of token substitutions only.
- Plus Jakarta Sans only approximates the reference display font; judge on device before Phase 4.
- App rename pending: keep the app name in one constant so the rename stays a one-line change.
- Decide later: delete the photo background selector (A7)? Keep the Lumo quote feature as is?

## Progress log

### Phase 1: done
Theming feature (System default, persisted in `SharedPreferencesAsync`, no flash, overlay reads the same value),
Warm Focus light + dark `ThemeData` from one builder, `AppPalette` ThemeExtension, Plus Jakarta Sans bundled,
Appearance row on the profile screen, debug-only design gallery, contrast / palette / repository / provider / widget tests.
Verified on device: saved `theme_mode` survives reinstall; dark renders correctly.

### Phase 2: done (colour sweep)
- ~860 `AppColors.*` and raw `Colors.*` uses across 41 files migrated to `context.palette.*` by a context-aware tool
  (foreground vs fill decides `accent` vs `accentText`, `background` vs `onAccent`). `AppColors` is now unreferenced
  (kept in `app_theme.dart` with a legacy note until Phase 4 cleanup).
- Helper methods that had no `BuildContext` now take one; `CircularProgressPainter` takes its colours from the caller and
  repaints when they change. Static colour caches in `focus_time_bottom_model.dart` became getters.
- 9 leftover `Color(0xFF82D65D)` (old green accent) mapped to `accent`.
- Buttons with status or accent fills now set a matching foreground (`onError` / `onAccent`); overlay loading/error
  scaffolds on `ink` use `onInk`; the global error widget uses `onError`.
- Dark status colours were retuned (error/success/warning/info) and `onError` / `onInk` are white in dark so the same token
  works for text on every status fill (test enforces >= 4.5:1) and icons on canvas (>= 3:1).
- New guard test `test/architecture/no_hardcoded_colors_test.dart` fails on raw hex, `AppColors`, or named Material colours
  outside `lib/core/theme/`.
- Decision A7 resolved by the user: the **background-image feature is removed**. Deleted `background_image_provider.dart`,
  `background_image_selector.dart`, `BackgroundImageConstants`, the long-press picker on the Focus tab and the "Theme"
  button on the active session; both screens now sit on the flat canvas. The Firestore field
  `userSettings.backgroundImage` is no longer read or written (orphaned, harmless). Wallpaper assets `theme1-6.png` and
  `image.png` (about 25 MB) were deleted.
- Also in this branch: images converted to WebP and the APK no longer bundles generator-only icon/splash assets (see
  `prompts/app-size-reduction.md`).

Known gaps left for Phase 3/4: `welcome_screen` / `save_session_screen` still sit on photos (use `onScrim`), layouts are
still the old ones, `AppColors` class removal, native splash day/night.

### Phase 3: done (reference screens)
- New design components in `lib/presentation/widgets/design/`: `AppPillButton`, `IconCircleButton` (+ `NotificationDot`),
  `PillChip`, `MessageCard`, `SessionCard`, `GoalCard`, `DurationText`, `WeekBarChart` (hatched highlight + tooltip),
  `FocusRingTimer`, `ControlDock`/`ControlButton`, `BlackBottomNav`, `HeroPanel` + `ScallopedBottomClipper`,
  `ScallopedProgressStrip`.
- Screens rebuilt as thin screen + pure view (`FocusHomeView`, `ActiveSessionView`) so they can be rendered and tested
  without Firebase: Welcome (hero panel, mascot placeholder for your art), Focus home (greeting, Today's Goal card with
  7-day chart, session setup tile, Today's sessions, Lumo card, Start button), Active session (ring timer, message card,
  scalloped strip, Ambient / Pause / Stop dock), `HomeScreen` uses the black bottom nav (same 5 tabs).
- Data: `userSettings.dailyGoalMinutes` (default 120) with a goal sheet; `dailyStats` last-7-days stream
  (`DailyStatsRepository`, `weekStatsProvider`, zero-filled).
- Behaviour kept: start-session flow, Lumo quotes, pause/resume/stop and the end-session sheet, allowed-apps drawer, audio
  sheet, `PopScope`, navigation guards. Removed with the redesign: the stopwatch pulse animation, the "notification
  banner" placeholder text, the 2M+ students / 4.7 stars claims on the welcome screen, and the old timer-circle widget,
  testimonial card and welcome photo (unreferenced).
- `lib/core/constants/app_info.dart` holds the app name for the UI (rename in one place).
- Layout in short windows: the control dock stays pinned and only the middle scrolls; below 320 dp tall the whole screen
  scrolls.
- Developer tool: `test/design/preview_render_test.dart` renders components and screens to PNG
  (`PREVIEW_DIR=<dir> flutter test test/design/preview_render_test.dart`); it is skipped in normal runs.

