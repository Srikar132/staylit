# Firestore rules for Staylit + remove dead broadcasts

Two items, both on the no-exceptions approval list (security rules; native service). Covers GitHub #13 (rules) and the security-review finding on `StaylitAccessibilityService`.

## Skills / code inspected
`firebase-security-rules-auditor`, `firebase-firestore`. Inspected: all `lib/data/repositories/*`, `parental_control_provider.dart`, `block_app_bottom_model.dart`, `firestore_parental_control.rules`, `firebase.json`, `StaylitAccessibilityService.kt` (broadcasts), grep for receivers.

## A. Firestore rules

### Problem
Repo only has rules for `parental_controls`. New project `staylit-4064f` is in production mode, so everything else is denied -> app unusable. No `firestore` block in `firebase.json`, so nothing is deployable.

### Collections actually used (from code)
| Path | Access pattern | Rule |
|---|---|---|
| `users/{uid}` (+ `profile/stats`, `profile/achievements`) | own doc, `set` merge from focus finish batch | read/write only `uid == auth.uid` (subcollections too) |
| `appLimits/{uid}/apps/{pkg}` | own | owner only |
| `blockedContent/{uid}` | own | owner only |
| `dailyStats/{uid}/days/{date}` | own | owner only |
| `parental_controls/{uid}` | own (PIN hash stored here) | owner only (keep existing semantics, drop the redundant `hasAll` update clause that blocks partial updates) |
| `focusSessions/{id}` | queries `where userId == uid`; batch update on finish | create: `request.resource.data.userId == uid`; read/update/delete: `resource.data.userId == uid`; `userId` immutable |
| `groups/{gid}` | public search `settings.isPublic == true`; `memberIds array-contains uid`; join = add own uid; leave; admin delete | read: signed in AND (`isPublic` OR uid in `memberIds`); create: `creatorId == uid` and `memberIds == [uid]`; update: existing member, OR self-join of a public group (only `memberIds`/`memberFocusTime`/`totalFocusTime` change, new `memberIds` = old + uid); delete: uid in `adminIds` |
| `groups/{gid}/members/{uid}` | member list; own doc written on join/leave; counters | read: member of group; write: own doc, or group admin |
| anything else | - | denied (default) |

### Decisions / assumptions
- Single file `firestore.rules` (replaces `firestore_parental_control.rules`; old file deleted, per "delete confirmed-dead").
- `firebase.json` gets `"firestore": {"rules": "firestore.rules"}`.
- Private-group lookup by ID for non-members will be denied (current UI only lists groups via queries; verified in `group_repository.dart`). If a "join by code" flow exists later it needs a rule change.
- No server-side validation of stat values (client-trusted; acceptable for FYP, note in report).
- No indexes file generated now; Firestore returns console links on first run of composite queries (`focusSessions userId+date+startTime`, `userId+startTime`). I will create `firestore.indexes.json` for those two so deploy is reproducible.

### Steps
1. Write `firestore.rules`, `firestore.indexes.json`, update `firebase.json`, delete old rules file.
2. Run rules check without deploy: `firebase deploy --only firestore:rules --dry-run --project staylit-4064f` (compile check).
3. After you create the database (API must be enabled): `firebase deploy --only firestore --project staylit-4064f`.
4. Update AGENTS.md references to the rules file name.

### Security
Owner-only everywhere except groups. Parental-control PIN hash stays owner-readable (same as before). No public writes.

## B. Remove dead broadcasts in `StaylitAccessibilityService.kt`

Review finding: `sendBroadcast(Intent("...WEBSITE_BLOCKED"/"CHALLENGE_FAILED"))` with `event_data` extras is implicit -> any app registering a runtime receiver can read blocked URL / package. Grep confirms **no receiver exists** in the app for either action, so they do nothing useful.

Decision: delete both (not `setPackage`) — nothing consumes them.
- Remove `sendEventToFlutter(event: Map)` private fun (its only job is the broadcast) and its caller in the website-block path; keep the surrounding `Log` and the existing real event path.
- In `sendChallengeFailedEvent`: remove the `Intent(...CHALLENGE_FAILED)` + `sendBroadcast` block and the `sendEventToFlutter(event)` call. Function then only logs; keep it (called at line ~396) so a future real event path can plug in. (`FocusModeManager.sendEventToFlutter` is a different, live EventChannel path — untouched.)

### Risk
None functional (no consumers). Manual test confirms blocking still works.

## Acceptance
- `grep -rn "sendBroadcast" android/app/src/main/kotlin/com/staylit/app/services/StaylitAccessibilityService.kt` -> none for these events.
- `firebase deploy --only firestore:rules --dry-run` compiles.
- `flutter analyze`, `flutter test` pass; Kotlin compiles.

## Manual test (you, on device, after DB exists + rules deployed)
1. Sign in with Google -> user doc appears in console `users/{uid}`.
2. Finish a focus session -> `focusSessions`, `dailyStats/{uid}/days/...` written, Home stats update.
3. Add app limit, blocked content -> docs under `appLimits/{uid}/apps`, `blockedContent/{uid}`.
4. Create group -> second account searches public groups, joins; both see members. Second account cannot read a private group.
5. In console Rules Playground / second account: reading another user's `users/{uid}` is denied.
6. Open a blocked website in Chrome during a session -> overlay still appears (broadcast removal didn't break it).
