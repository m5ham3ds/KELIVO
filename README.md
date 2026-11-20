# Kelivo — Android Edition

This Kelivo source snapshot is prepared for Android APK builds only. The Android app, native Kotlin/Java integration, Android resources, and ARM64 PRoot workspace runtime are retained. Separate iOS, Windows, Linux desktop, macOS, and Web runner projects/native payloads are removed.

## Build and CI

The **Android ARM64 Build & Essential Arabic Checks** workflow runs on pushes to `main`, pull request updates, and manual dispatch. It checks the Android-only source tree, resolves app dependencies, runs the focused Phase 13E–13P Skill regression lanes and Arabic localization parity checks, then analyzes the app's `lib/`, `test/`, and `integration_test/` trees.

The workflow runs the complete root Flutter unit/widget suite, then runs the independent tests of the vendored path packages (`mcp_client`, `downsize`, `flutter_math_fork`, `markstream`, and `terminal_view`) from each package's own directory. It also runs the Android JVM/Robolectric suite, the Phase 13P Skill lifecycle test on Android for every push to `main`, and builds an ARM64-only APK. Manual dispatch supports `release` or `debug` builds and can explicitly request the Android Skill E2E test.

GitHub Actions uploads the APK and SHA-256 checksum only when the build succeeds. The report job separately uploads `KELIVO_BUILD_REPORT.md` and available raw logs after failures as well. See [the Arabic build automation guide](phases/BUILD_AUTOMATION_REPORT_AR.md) for the exact stages and artifact locations.

Toolchain versions: Flutter 3.47.6, Java 17, Android NDK 28.2.13676358, and CMake 3.22.1. See [the Android build guide](phases/ANDROID_BUILD_AR.md) and [the Android-only audit](phases/ANDROID_ONLY_AUDIT.md).

## Supported interface languages

Kelivo supports English, Arabic (right-to-left), Simplified Chinese, and Traditional Chinese. Arabic localization currently covers 97.49% of the 4,696 application messages; technical identifiers, protocol names, provider brands, code samples, and a small set of specialist strings intentionally retain their original form. Translation key and placeholder parity is checked in CI. See [`docs/localization/ARABIC_STATUS.md`](docs/localization/ARABIC_STATUS.md) for the current coverage report.

## Development roadmap

See [`phases/README.md`](phases/README.md) for the master plan, current Phase 12 work, phase records, implementation reports, and acceptance requirements.

## License

See [LICENSE](LICENSE). Vendored dependencies retain their individual license files and notices.


### Phase 13K.5 — CLI Evidence and Generic Local Script Capability

Follow-up to CI run `43782785649`: CLI requirements now match discovered command evidence by executable name/basename, and generic `local_script` declarations without entrypoints map to a conditional application capability instead of an unknown capability. Unknown script extensions remain blocked, and profile-level CLI evidence still requires a verified profile identity and timestamp. See `phases/PHASE-13K.5-CLI-AND-GENERIC-SCRIPT-CAPABILITY-FIX-AR.md`. Static CI/Android audits pass locally; Flutter tests and APK build remain to be confirmed by GitHub Actions.
