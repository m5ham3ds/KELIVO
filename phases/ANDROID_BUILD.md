# Android-only build and CI

This repository targets Android only. iOS, Windows, Linux desktop, macOS and Web runner projects/native payloads have been removed. Flutter/Dart shared code used by Android and the Linux PRoot userland remain.

## Automatic GitHub Actions

`.github/workflows/android-build.yml` runs automatically on every branch `push` and on `pull_request` open/update events. No manual **Run workflow** click is needed after committing/uploading source files to the GitHub repository. The workflow intentionally has no path filter, so documentation or configuration updates do not accidentally skip CI.

Automatic runs use `release`. Manual dispatch remains available to choose `release` or `debug`.

## Artifacts

- `Kelivo-Android-arm64-v8a-*`: installable ARM64 APK plus SHA-256, uploaded only after successful checks/build.
- `Kelivo-Build-Report-*`: `KELIVO_BUILD_REPORT.md`, the complete GitHub Actions build-job log when downloadable, per-stage command logs, metadata and warning/error matches. This artifact is uploaded even when an earlier build step fails, provided the report job can run.

The report records repository/ref/commit/event, Flutter/Dart/Java/NDK/CMake versions, command-stage outcomes and durations, official GitHub step conclusions (including skipped steps), APK size/checksum when produced, and every detected warning/deprecation/error/failure-pattern line with its log reference. Pattern matches are diagnostic aids; inspect the original logs before treating a match as the root cause.

## Pipeline

1. Checkout and Android-only/ARM64/PRoot audit.
2. Java and Flutter setup and toolchain version capture.
3. Android SDK license acceptance plus pinned NDK/CMake install.
4. One Flutter dependency resolution (the markstream path dependency is resolved transitively by the app).
5. Format only changed first-party Dart files; generate/check localization only when ARB or `l10n.yaml` inputs change.
6. Analyze all production `lib`, `test` and `integration_test` sources.
7. Run Environment lifecycle, Phase 14A, Phase 14B, Phase 14E.2, Gemini/OAuth, Phase 14C.4, Phase 13Q/14D real STDIO and five vendored local-package test suites.
8. Run the complete Android JVM/Robolectric suite and Phase 13P Android Emulator E2E.
9. Build the ARM64 APK, inspect the actual archive ABI, generate SHA-256 and upload the APK artifact.
10. A dependent report job downloads the build logs, generates Markdown and uploads the report/raw logs.
8. A dependent report job downloads the completed build-job log through the GitHub Actions REST API (`actions: read` only), generates Markdown, and uploads the report/raw logs even after a build failure.



### Test scope

The active workflow does not run the complete root Flutter unit/widget suite or every historical focused suite for Phases 13E–13O. Static analysis is not a substitute for those test suites. The named focused gates are the current Phase 14 and Phase 13Q/14D/13P regression groups described above.

Toolchain versions: Flutter 3.47.6, Java 21, Android NDK 28.2.13676358 and CMake 3.22.1. Release builds without `android/key.properties` use the debug signing key; this is suitable for installation/testing, not Play Store publishing.

## Latest verified run — CI #208

Run: https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283
Commit: `77736b783d55752a35a3aeb3b66b6b6dce7e87f1`
APK: 41,943,583 bytes; `arm64-v8a` only; SHA-256 `29fa1b9db0223dd0b9c6d8f170af3b86f6d44f2f5dd88a992843bd09f907f6fa`.
APK Artifact: `15167472926`; Build report Artifact: `15167378117`; raw diagnostics: `15167717401`.

See [BUILD_AUTOMATION_REPORT_AR.md](BUILD_AUTOMATION_REPORT_AR.md) for the Arabic guide.
