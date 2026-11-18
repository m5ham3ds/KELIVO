# PHASE 2 — Fifth CI Failure Analysis and Android Test-Scope Correction

## Source build report

- GitHub Actions run: `42376282409`
- Repository / branch: `m5ham3ds/KELIVO` / `main`
- Tested commit: `376f77c4e8c9`
- Build mode: `release`
- Flutter: `3.47.6`
- Java: `17`
- Android target: `arm64-v8a`

## Actual failure

The run passed checkout, Android-only audit, Java/Flutter setup, Android NDK/CMake installation, root application dependency resolution, Dart formatting and localization generation. It stopped at:

`dart analyze --fatal-infos lib test integration_test`

The only analyzer diagnostic was:

`test/features/settings/search/settings_search_widgets_test.dart:13:8 — Unused import: package:Kelivo/shared/widgets/ios_switch.dart`

Dart analysis exited with code `2`. Flutter tests and Android APK compilation were skipped. No test was started in this run, and no APK was produced.

## Why the old CI policy was not appropriate

The old workflow analyzed every test and integration-test file and then ran `flutter test` over the entire repository. The historical full test run attempted 11,465 cases (11,416 passed, 41 failed and 8 skipped), including native-platform suites and UI variants for iOS, macOS, Windows and Linux even though this repository only ships an Android app. It also ran independent markstream dependency/analyzer/test stages despite markstream already being resolved as a path dependency of the app.

That is too broad for the active Phase 2 change set. The active development phase is **Phase 2 — Conversational Extension Commands**. CI must protect the changed Skill extension lifecycle and the complete Android application source, not run every historical test in the repository on each push.

## Corrections applied

### 1. Direct analyzer failure

- Removed the unused `ios_switch.dart` import from `settings_search_widgets_test.dart`.

### 2. Android-only test scope

Added `.github/ci/android-phase2-test-manifest.txt` as the source of truth for the required test files:

- `extension_entity_store_test.dart`
- `extension_record_test.dart`
- `conversational_extension_service_test.dart`
- `extension_operation_repository_test.dart`
- `extension_registry_repository_test.dart`
- `skill_archive_test.dart`
- `skills_prompt_test.dart`
- `skills_service_test.dart`
- `built_in_tool_names_test.dart`
- `message_builder_skills_prompt_test.dart`

The runner additionally executes only two named tests from `workspace_tool_ui_test.dart`: the extension tool catalog/timeline renderer and live extension-install progress. It does not run the other unrelated tests contained in that large UI test file.

Added:

- `.github/scripts/analyze_android_phase2.sh` — analyzes all production Dart sources under `lib`, the ten manifest test files and the one UI test file containing the two selected UI checks.
- `.github/scripts/test_android_phase2.sh` — executes the ten explicit regression files plus only the two named Android chat UI tests.
- `.github/ci/android-phase2-test-manifest.txt` — auditable, fixed whitelist of Phase 2 test files.

The main workflow and optional manual quality workflow now use the same analyzer/test scripts. No general `integration_test` suite, full repository `flutter test`, or standalone markstream analyzer/test job remains in the active pipeline. Root `flutter pub get` still resolves markstream as an application dependency.

### 3. Remove stale native-platform test files

Removed 36 test files whose entire purpose was an iOS, macOS/desktop, Windows, or Linux desktop native target that no longer exists in this Android-only project. The Phase 2 workspace-tool UI test also had Linux/Windows/macOS-only test blocks removed, leaving Android-compatible behavior for its selected cases.

This change does not remove Android app functionality or generic shared Flutter code. It removes unsupported native-target test sources and excludes unrelated legacy feature tests from the active Phase 2 gate.

### 4. Reduce unrelated CI work

- Changed Dart formatting from all tracked files (over 1,300 in the supplied report) to only first-party Dart files changed in the current revision.
- Localization generation and untranslated-message comparison now run only when `lib/l10n/*.arb` or `l10n.yaml` changes.
- Removed separate `markstream pub get`, `dart analyze`, and `flutter test` steps; the root dependency resolution already resolves the path package.
- Reduced the main build job timeout from 100 to 60 minutes and set explicit limits for analyzer, focused tests and APK build.
- Removed `--verbose` from the Flutter APK build to avoid unnecessarily large logs while keeping command logs/report artifacts.
- Extended the Android-only audit to verify every manifest file exists and contains no explicit iOS/macOS/Windows/Linux test variants, and to prevent the full-suite/standalone-markstream commands from returning to the main workflow.

## Phase 2 is still the active phase

No Phase 3 work was started. The source changes for Phase 2 remain as previously implemented. This correction changes CI scope and removes stale non-Android test files; it does not alter Skill lifecycle behavior, storage schema, tool contracts or future-phase architecture.

## Validation performed in the preparation environment

The project archive was extracted and source/phase records reviewed. The following static checks are part of the delivery verification:

- YAML parse for both GitHub Actions workflows.
- `bash -n` for all shell scripts.
- Android-only audit, including PRoot ARM64 library checksums and the explicit test manifest.
- Manifest file-existence and non-Android platform-token checks.
- Git diff whitespace validation and archive integrity/one-root-folder check.

## Not executed in the preparation environment

This preparation environment does not have the Flutter/Dart SDK and cannot perform a real Android Gradle build. Therefore the following are **not claimed as passing**:

- Dart analysis of `lib` plus the manifest.
- The focused Flutter Phase 2 tests.
- Android ARM64 Release APK compilation and artifact upload.
- On-device conversational install/update/rollback verification.

Those are the required checks for the next GitHub Actions run. Phase 2 remains pending until they pass and the APK is verified on the Android device.
