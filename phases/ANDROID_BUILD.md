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
6. Analyze all production `lib` code and the explicit Phase 2 test manifest, then run only the named Android Phase 2 regression tests.
7. Android ARM64 APK build, SHA-256 generation and APK artifact upload.
8. A dependent report job downloads the completed build-job log through the GitHub Actions REST API (`actions: read` only), generates Markdown, and uploads the report/raw logs even after a build failure.



### Test scope

The active workflow does not run the complete repository test tree. Its whitelist is `.github/ci/android-phase2-test-manifest.txt`, plus two named chat UI regression tests for the extension-tool catalog and live install progress. No general integration tests or iOS/macOS/Windows/Linux platform variants run in this Phase 2 Android gate. All production Dart sources under `lib` are still analyzed. The independent markstream test/analyzer jobs were removed because markstream is unchanged and is already resolved as an application dependency.

Toolchain versions: Flutter 3.47.6, Java 17, Android NDK 28.2.13676358 and CMake 3.22.1. Release builds without a supplied keystore use Android's default debug signing; this is suitable for local installation/testing, not Play Store publishing.

See [BUILD_AUTOMATION_REPORT_AR.md](BUILD_AUTOMATION_REPORT_AR.md) for the Arabic guide.
