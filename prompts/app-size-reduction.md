# App size reduction

## Goal
Shrink the shipped APK/AAB without changing behavior. Measured on `flutter build apk --release --target-platform
android-arm64 --analyze-size`.

## Result so far (applied, Dart/asset level only)

| Change | Saved |
|---|---|
| Removed the wallpaper feature assets (`theme1-6.png`, `image.png`) | ~25 MB source assets |
| Images -> WebP (resized album art, backgrounds, mascot, logos): 5.8 MB -> 0.23 MB | ~5.5 MB |
| Stopped bundling generator-only `assets/icons/` and `assets/splash/` (launcher/splash tools read them from disk) | ~1.2 MB |
| Removed 5 dependencies with zero imports: `shimmer`, `smooth_page_indicator`, `flutter_svg`, `http`, `permission_handler` (+ transitive `vector_graphics*`, `permission_handler_*`) | small native + Dart |

Release arm64 APK is now **47.9 MB** (the last release build in `build/` was 117 MB, an all-ABI fat APK from before these
changes; not a like-for-like number). Merged manifest permissions are identical before and after (21 = 21, diffed).

Breakdown of the 47.9 MB: `assets` 23.6 MB (almost all of it the six music files), `lib` 19.1 MB (arm64 native: Flutter
engine + app + plugins), `res` 2.3 MB, `classes.dex` 2.1 MB.

## Not done yet, needs your decision

1. **Re-encode the six `song*.mp3` files (23 MB).** Biggest remaining win: 96 kbps stereo should bring them to roughly
   8 MB (about -15 MB APK). Same filenames and format, so no code change; originals stay in git history. Needs an mp3
   encoder: no `ffmpeg` is installed. Either install it yourself (`winget install Gyan.FFmpeg`) or approve me installing a
   packaged ffmpeg into an isolated venv (an automated safety check blocked that without your sign-off).
   Audible trade-off: ambient focus music, fine at 96 kbps; say if you want 128 kbps (about -9 MB instead).
2. **Ship an Android App Bundle (`flutter build appbundle`)** or `--split-per-abi` APKs. Users then download only their
   ABI (~28 MB for arm64 today after item 1 it would be ~13 MB of non-audio plus audio). Build setting only.
3. **`--obfuscate --split-debug-info=build/symbols`** for release: smaller `libapp.so`, harder to reverse. Keep the
   symbols folder for crash decoding. Build flag only.
4. **R8 / resource shrinking**: Flutter enables these for release by default. Because enforcement classes are
   manifest-registered and called by name, do not tighten keep rules without testing every blocker on a device; no
   Gradle change was made.
5. **`firebase_analytics`** is declared but unused in `lib/`; removing it saves native size and is tracked by issue #38.
6. `lottie` is used in one file: check whether that animation justifies the package.

## Risks
- WebP: verify on device that album art, welcome/save backgrounds, mascot and splash icon look right (visual check only).
- Removing `permission_handler`: Dart never imported it; permissions go through `PermissionManager.kt`. The merged
  manifest diff proves nothing changed, but run the permission flow once on a device.

## Checks run
- `flutter analyze`, `flutter test` (78 pass) after the changes; release build succeeded.

## Manual test steps
1. Install the release APK; open Focus -> music picker: all six album covers render.
2. Welcome screen (new account) and save-session screen backgrounds render.
3. Onboarding mascot, Lumo logo and splash icon render.
4. Run the full permission flow and one focus session with blocking.

---

## Update (before the first GitHub release)

### Where it stands
- Last release build in `build/`: `app-release.apk` = **87.5 MB**. That is an all-ABI fat APK (arm64 + armv7 + x86_64 native libs), which is why it is bigger than the 47.9 MB arm64 number above.
- `assets/` is 25 MB; **23.9 MB of it is the six `song*.mp3`** (5.3 / 5.0 / 4.4 / 3.5 / 3.3 / 2.4 MB). Everything else (images, fonts, launcher icons) is under 2 MB, WebP already.
- R8 and resource shrinking already run for release (Flutter default; `mapping/release` exists). No keep-rule changes (section 4 above still applies: manifest-registered enforcement classes).
- `lottie` is used by one file (`blocked_app_overlay.dart`).
- `firebase_analytics` has zero uses in `lib/` or native; issue #38 asks to wire or remove it.

### Plan, biggest win first
1. **Re-encode the six mp3s** to 64 kbps mono 44.1 kHz (ambient focus music; mono is fine for it). Expected 23.9 MB -> about 4.5 MB (**about -19 MB**). Same filenames and format, no code change. Originals stay in git history. Needs an encoder: none installed.
2. **Release artifacts: per-ABI APKs** (`flutter build apk --release --split-per-abi`, ship `arm64-v8a` for the GitHub release; armeabi-v7a as an extra file for old phones) and an **AAB** for Play later. Expected arm64 APK about 28 MB today, about 10 MB after step 1 and R8, no code change.
3. **`--obfuscate --split-debug-info=build/symbols`** on release builds (smaller `libapp.so`). Build flags only. Keep `build/symbols` (not committed) for crash decoding.
4. **Remove `firebase_analytics`** (unused; saves its native SDK) once you decide on #38. Removing a dependency touches `pubspec.yaml` only; Gradle picks up the change.
5. Keep `lottie` unless you want that one overlay animation replaced by a static image; decide separately.
6. Re-check the new welcome art: `welcome.webp` 178 KB + two brains 182 KB. Could drop to quality 80 for about -150 KB. Visual check needed, low value; skip unless you ask.

### Encoder options (pick one; nothing is installed without your OK)
- (a) You run `winget install Gyan.FFmpeg`, I use it.
- (b) I install `imageio-ffmpeg` (a pip package that ships an ffmpeg binary) into an isolated venv under the scratchpad, run the encode there, delete the venv. Nothing system-wide changes.

### Risks
- Audio quality at 64 kbps mono is audibly lower than the 128+ kbps stereo originals; fine for background ambient, noticeable on a headset. 96 kbps mono is the safer middle (about -17 MB).
- Obfuscated crash traces need the symbols folder to read.

### Acceptance
- Per-ABI arm64 release APK around 30 MB (the first estimate of under 12 MB was wrong: see Measured). Check with `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols`).
- All six songs still play at the same names in the music picker; the focus cue still plays.
- `flutter analyze` and `flutter test` pass; manual run of the permission flow and one blocked session on a device.

### Manual test steps
1. Install the arm64 APK from `build/app/outputs/flutter-apk/`. Open Focus -> music picker, play each song for 10 s.
2. Start a focus session, open a blocked app, confirm the Lit sheet.
3. Run the permission flow once.

### Measured (2026-11-26, after steps 1-3)
`flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols`:

| APK | Size |
|---|---|
| arm64-v8a (ship this one) | **29.7 MB** |
| armeabi-v7a | 27.1 MB |
| x86_64 (emulators) | 31.1 MB |
| all-ABI fat APK, before (not split) | 87.5 MB |

The six songs went 23.9 MB -> 6.0 MB (64 kbps mono 44.1 kHz; durations unchanged). arm64 APK contents now: `libflutter.so` 11.2 MB
(the Flutter engine, fixed cost), `libapp.so` 5.9 MB (your Dart), assets 6.9 MB (6 MB of it music), `classes.dex` 2.2 MB, `res` 2.7 MB
(mostly the native splash PNGs: 14 density copies), the rest under 1 MB. About 19 MB of the 29.7 MB is engine + code and cannot be
trimmed from the app side.

### Left on the table (each small, each needs a decision)
- Splash PNGs -> lossless WebP (about -1 MB; touches the generated native splash resources, flutter_native_splash regenerates them).
- `useLegacyPackaging` for native libs (about -7 MB download, but a bigger installed app and a slightly slower first start): not recommended.
- Remove `firebase_analytics` after deciding #38 (about -0.3 MB dex), replace `lottie` in one overlay (small).
- Duplicate Lit artwork lives both in Flutter assets and Android res (about 0.15 MB).
