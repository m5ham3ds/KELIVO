# Kelivo — Android Edition

This Kelivo source snapshot is prepared for Android APK builds only. The Android app, native Kotlin/Java integration, Android resources, and ARM64 PRoot workspace runtime are retained. Separate iOS, Windows, Linux desktop, macOS, and Web runner projects/native payloads are removed.

## Build and CI

The **Android ARM64 Build & Essential Arabic Checks** workflow runs automatically on every branch push and pull request update. It performs the Android-only/release-hardening audits, resolves dependencies, checks Arabic ARB key/placeholder parity, generates localizations, runs only two focused tests (Arabic RTL rendering and persisted Arabic locale), then builds the ARM64 APK. It intentionally does not run the historical Phase 7–12 regression manifest, broad Dart analysis, formatter sweeps, or unrelated UI tests in the release build. Automatic runs use `release`; manual dispatch allows `release` or `debug`.

On every run, GitHub Actions uploads the APK and SHA-256 only when the build succeeds. A separate report job uploads `KELIVO_BUILD_REPORT.md` and complete available raw logs even when an earlier build stage fails. See [BUILD_AUTOMATION_REPORT_AR.md](BUILD_AUTOMATION_REPORT_AR.md) for where to find the report and how it is generated.

The `share_plus` dependency is pinned to the compatible 13.3.1 line so its `win32` 6.x requirement intersects with `flutter_secure_storage` 11.2.0. Toolchain versions: Flutter 3.47.6, Java 17, Android NDK 28.2.13676358, and CMake 3.22.1. See [ANDROID_BUILD_AR.md](ANDROID_BUILD_AR.md) for the Arabic build guide and [ANDROID_ONLY_AUDIT.md](ANDROID_ONLY_AUDIT.md) for cleanup details. `Manual Arabic Localization Checks` is retained for the same two focused localization tests without performing a full Android build.

## Supported interface languages

Kelivo supports English, Arabic (right-to-left), Simplified Chinese, and Traditional Chinese. Arabic localization currently covers 97.49% of the 4,696 application messages; technical identifiers, protocol names, provider brands, code samples, and a small set of specialist strings intentionally retain their original form. Translation key and placeholder parity is checked in CI. See [`docs/localization/ARABIC_STATUS.md`](docs/localization/ARABIC_STATUS.md) for the current coverage report.

## Development roadmap

See [`phases/README.md`](phases/README.md) for the master plan, current Phase 12 work, phase records, implementation reports, and acceptance requirements.

## License

See [LICENSE](LICENSE). Vendored dependencies retain their individual license files and notices.


### Phase 13K.5 — CLI Evidence and Generic Local Script Capability

Follow-up to CI run `43782785649`: CLI requirements now match discovered command evidence by executable name/basename, and generic `local_script` declarations without entrypoints map to a conditional application capability instead of an unknown capability. Unknown script extensions remain blocked, and profile-level CLI evidence still requires a verified profile identity and timestamp. See `phases/PHASE-13K.5-CLI-AND-GENERIC-SCRIPT-CAPABILITY-FIX-AR.md`. Static CI/Android audits pass locally; Flutter tests and APK build remain to be confirmed by GitHub Actions.
