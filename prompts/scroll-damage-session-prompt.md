# Paste this into a new Claude Code session (repo root, on a new branch off main)

Implement **Scroll damage** phase 1 (native counter + persistence + Flutter wiring) for Staylit.

Read first, in this order:
1. `AGENTS.md` (project rules; native services, rules and permission handling need the prompt-approval step; never install or run the app on my phone)
2. GitHub issue #41 (`gh issue view 41`): full context, what exists, proposed design, acceptance, risks
3. `lib/presentation/screens/focus/scroll_mood.dart`, `lib/presentation/widgets/design/scroll_damage_card.dart`, `lib/presentation/screens/focus/focus_home_data.dart` (`ScrollDamageData`), `lib/presentation/screens/focus_screen.dart` (`_showScrollDamageSheet`)
4. `android/app/src/main/kotlin/com/staylit/app/services/StaylitAccessibilityService.kt` (scroll events, `detectYouTubeShortsEnhanced`, `detectInstagramReels`), `services/shared/BlockingConfig.kt`, `MainActivity.kt` (event channel, `sendEventToFlutter`), `lib/services/native_service.dart`

Scope of this session = phase 1 only:
- Native counter in the accessibility service: allow-listed apps (Instagram Reels, YouTube Shorts, TikTok, Facebook Reels), debounced page-change counting, per app / session / local day, persisted in SharedPreferences, enabled only when `scrollDamageEnabled` is true (sync that flag to native through the existing channel)
- Counts batched to Flutter over the existing event channel; Flutter writes `scrollStats/{uid}/days/{date}` (set-merge with increments, fire-and-forget, `tzOffsetMinutes`, same day key as `DailyStat.dayKey`)
- Add owner-only Firestore rules for `scrollStats/{uid}/days/{date}` and deploy with `firebase deploy --only firestore`
- `scrollDamageProvider` -> `ScrollDamageData` -> the existing Home card (real count, 7-day bars, "down N% vs yesterday")
- Pure logic (debounce/counter state machine, day rollover, trend text) with unit tests

Out of scope (separate sessions): the floating mascot overlay, break/redirect interventions.

Rules for this session:
- Follow AGENTS.md section 2: inspect the code, write `prompts/scroll-damage-native.md` (goal, code inspected, decisions, files, privacy, acceptance, checks, exact manual device test steps), then ask me once to approve it with the question panel. Do not write code before I say Yes.
- Never store or log what is on screen: counts and timestamps only.
- Keep the accessibility foreground service and its notification channel intact.
- Run `flutter analyze`, `dart format` on changed files only, `flutter test`; compile Kotlin with `cd android && ./gradlew :app:compileDebugKotlin --offline -q`. Do not install or launch the app.
- Commit in small commits on a feature branch, do not commit `prompts/`, `designs/` or `.md` files unless I ask, push, and open a PR into `main` (do not merge until I say).
- Finish with the short report: What I did / Test / Needs your attention.
