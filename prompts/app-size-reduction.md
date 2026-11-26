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
