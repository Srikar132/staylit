# Fix: one session-finish path, correct stats, consistent units (GitHub #14 and #16)

## Goal
Every way a focus session can end writes the same, correct data, and stored durations have one documented unit.

- **#14**: auto-complete, manual end + save, and discard write different data. Manually saved sessions never reach user
  totals or daily stats; discarded sessions are deleted (lost as negative samples).
- **#16**: `UserModel.totalFocusTime` is documented and formatted as milliseconds but is written in minutes.

## Skills / files read
- `lib/presentation/providers/focus_session_provider.dart`: `_handleAutoCompletion` -> `_saveCompletedSession`,
  `completeSessionWithNotes`, `discardSession`, `_computeCompletionRate`, `startSession` (creates the doc up front).
- `lib/data/repositories/focus_session_repository.dart`: `completeSession` (batch: session + `users` + `dailyStats`),
  generic `updateSession`, `deleteSession`, `streamTodaySessions`, `getSessionHistory`.
- `lib/data/models/focus_session_model.dart`, `lib/data/models/user_model.dart`,
  `lib/presentation/screens/save_session_screen.dart` (calls `completeSessionWithNotes` / `discardSession`).
- Native `FocusSessionManager.kt`: `actualDuration` is **minutes** (`totalElapsed / 60000`, floor) and
  `session_completed` / `session_auto_completed` carry it.
- Grep results: `todaySessionsProvider` and `getSessionHistory` have **no consumers yet** (Phase 3 will add one);
  `UserModel.formattedTotalFocusTime` and `.totalFocusTime` have **no readers** in `lib/presentation`.
- Skills to use at build time: `dart-add-unit-test`, `dart-run-static-analysis`.

## What exists today
| Path | Session doc | `users` totals | `dailyStats` |
|---|---|---|---|
| Timer finishes (auto) | status `completed`, endTime, duration, rate | +minutes, +1 session | +minutes, +1, +1 completed |
| User ends early, then Save | status `completed`, duration, rate, **notes, tag, completedAt (not in model)** | **none** | **none** |
| User ends early, then Discard | **doc deleted** | none | none |

`status` is only ever `active` or `completed`; native already distinguishes `ended_early`. Because totals use
`FieldValue.increment(actualDuration)` with minutes, **existing data is already in minutes**: #16 is a code/doc
bug, not a data migration.

## Decisions and assumptions (reply "no" and name the item to change)
1. **One unit for stored durations: minutes** (as already written). Fix the `UserModel` comment and
   `formattedTotalFocusTime` to treat the value as minutes. No rename of the Firestore field now (a rename needs a
   migration; it belongs with the schema consolidation, issue #20).
2. **One repository method `finishSession(...)`** replaces `completeSession` and the ad-hoc `updateSession` call. It is
   built around a small pure function that computes the field maps to write, so the logic is unit-testable without a
   Firestore fake.
3. **Status values:** `completed` (completion rate >= 100), `ended_early` (< 100), `discarded`.
   Stopwatch sessions have no planned duration, so they count as `completed` (existing rate logic).
   **`endReason` (as built) records *how* it ended, separate from status:** `timer_finished`, `user_ended`,
   `user_discarded`.
4. **What counts toward stats:** `completed` and `ended_early` both add their real minutes and +1 `totalSessions`;
   only `completed` adds to `dailyStats.completedSessions`; `discarded` adds nothing.
5. **Discard keeps the doc** with status `discarded` instead of deleting it (negative samples for the personalization
   work). `streamTodaySessions` and `getSessionHistory` filter discarded docs out client-side so lists never show them.
6. **Offline-safe finish:** Firestore only completes `batch.commit()` on server acknowledgement, so awaiting it hangs
   offline (see #12). `finishSession` starts the commit, logs failures, and returns without waiting for the server, so
   the Save/Discard screens never freeze. Trade-off: a rules-denied write is only logged. (The start path, #12, is a
   separate change and is **not** touched here.)
7. **Double-finish guard:** the notifier remembers the last finished session id and ignores a second finish for it.
8. **Date key:** stats keep using the device-local date at finish time (existing behavior). Sessions that cross midnight
   are attributed to the finish day. Timezone-safe keys are issue #27.
9. Minute granularity stays (native floors to minutes, so a 24m59s session records 24).

## Files expected to change
- `lib/data/models/focus_session_model.dart`: add `endReason`, `notes`, `tag`; status constants; tolerant parsing of
  old docs (missing fields). Drop `completedAt`.
- `lib/data/repositories/focus_session_repository.dart`: add `finishSession` + pure plan function; remove
  `completeSession`; filter discarded in `streamTodaySessions` / `getSessionHistory`; keep `deleteSession` only if
  something still calls it (grep first).
- `lib/presentation/providers/focus_session_provider.dart`: `_saveCompletedSession`, `completeSessionWithNotes` and
  `discardSession` all call `finishSession`; compute status from the completion rate; add the double-finish guard.
- `lib/data/models/user_model.dart`: minutes semantics for `totalFocusTime` and `formattedTotalFocusTime`.
- New tests under `test/`.
- Not touched: native Kotlin, Firestore rules, manifests, platform channels, UI screens.

## Requirements
- No behavior change to timer, native session, navigation (`endingWithSave`, `completed`, `idle`) or the
  `_isManuallyEnding` race handling.
- Existing documents without the new fields must still parse.
- The plan function never returns negative minutes and clamps the completion rate to 0..100.
- Dart rules from the theming work apply: small functions, no `dynamic` leaking, `///` docs on the new repository API.

## Security / privacy
No new data is collected (notes and tag were already written). No rules changes. Rules for these collections do not
exist in the repo yet (#13): this change does not widen what clients can write.

## Acceptance criteria
- Auto-complete, manual save and discard each leave the session doc in a terminal status (`completed`, `ended_early`,
  `discarded`) with `endReason` set.
- `completed` and `ended_early` increase `users.totalFocusTime` (minutes), `users.totalSessions` and the day's
  `dailyStats`; `discarded` changes neither.
- The Save screen finishes immediately in airplane mode; after reconnecting, the session and totals appear exactly once.
- `formattedTotalFocusTime` shows hours/minutes correctly for a value in minutes.
- Old session docs still load.

## Checks to run
- `dart format` on the changed files only, `flutter analyze`, `flutter test`.
- New unit tests: plan function for completed / ended_early / discarded, zero and negative minutes, completion rate
  clamp, stopwatch (planned 0), `UserModel.formattedTotalFocusTime` (0, 59, 60, 125 minutes), `FocusSessionModel`
  parsing of an old doc and a new doc.

## Manual test steps (device)
1. Start a short session (1 min) and let it finish: Firestore `focusSessions/{id}` is `completed`; `users/{uid}`
   `totalFocusTime` +1, `totalSessions` +1; `dailyStats/{uid}/days/{today}` updated.
2. Start a session, end it early, Save with a note and tag: doc is `ended_early` with notes/tag/endReason; totals and
   daily stats increased.
3. Start a session, end it early, Discard: doc stays with status `discarded`; totals unchanged.
4. Airplane mode, repeat step 2: Save returns instantly; turn the network on; one set of writes lands, totals +1 only once.
5. Kill the app on the save screen and reopen: no crash, no double counting.

## Out of scope / follow-ups
Offline **start** hang (#12), stats consolidation and streaks (#20), timezone-safe day key (#27), interruptions in the
schema (#22), the Firestore field rename.
