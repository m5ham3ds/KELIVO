# PHASE 2 — Sixth CI Failure Analysis and Correction

## Source build report

- GitHub Actions run: `42389886131`
- Repository / branch: `m5ham3ds/KELIVO` / `main`
- Tested commit: `aeda913d0ba9`
- Event: `push`
- Build mode: `release`
- Flutter: `3.47.6`
- Java: `17`
- Android target: `arm64-v8a`

## Actual failure

The run passed all setup and dependency stages:

- Android-only source audit.
- Java 17 and Flutter 3.47.6 setup.
- Android NDK `28.2.13676358` and CMake `3.22.1` installation.
- Root Flutter application dependency resolution.
- Conditional localization generation and untranslated-message check.

It stopped in `dart analyze --fatal-infos` while analyzing the complete production `lib` tree, the ten explicit Phase 2 manifest test files, and the selected Android chat UI test file.

The three analyzer errors were all in `test/features/chat/widgets/workspace_tool_ui_test.dart`:

1. Line 641: `unawaited` was undefined because the test did not import `dart:async`.
2. Lines 705–706: `ToolPermissionMode` was undefined because the test did not import `core/models/tool_permission_mode.dart`.

The enum is defined in `lib/core/models/tool_permission_mode.dart`; the test was using it without a direct import. These were analyzer errors, not failed widget assertions.

Because analysis stopped with exit code `3`, the focused Flutter tests and Android ARM64 APK build were skipped. No APK was produced in this run.

## Additional CI inefficiency found

The formatter step reported that no base commit was available and consequently formatted 2,285 tracked first-party Dart files. Only one file needed an actual formatting change. This happened because the run was made against the repository's root/initial commit, which has no parent commit to diff against. The main workflow already uses `actions/checkout` with `fetch-depth: 0`; there is no additional history to fetch for a root commit.

A missing comparison base must not cause a repository-wide formatting sweep. The formatter now records empty patch/input files and skips this optional step when no parent/base commit exists. For subsequent commits, it continues to format only Dart files changed between the base and current commit.

## Corrections applied

### 1. Fix the analyzer imports

Updated `test/features/chat/widgets/workspace_tool_ui_test.dart` with the direct imports it requires:

- `dart:async` for `unawaited`.
- `package:Kelivo/core/models/tool_permission_mode.dart` for `ToolPermissionMode`.

The permission enum and method usages remain unchanged; this is an import-only correction, not a behavior or policy change.

### 2. Retain the formatter correction already produced by CI

Applied the single formatting-only patch captured by the failed run to:

- `test/features/home/services/built_in_tool_names_test.dart`

### 3. Prevent initial-commit formatter sweeps

Updated `.github/scripts/format_changed_dart.sh` so a missing base commit results in an explicit skip rather than a `git ls-files` scan of all Dart sources and tests. On all later commits, it still formats and verifies only changed first-party Dart files.

### 4. Keep the Phase 2 Android CI scope unchanged

No full repository test sweep was reintroduced. CI still:

- analyzes all production Dart sources under `lib`;
- analyzes the ten files in `.github/ci/android-phase2-test-manifest.txt`;
- analyzes the one selected Android UI test file needed for the two named UI regressions;
- runs only those ten regression files plus the two named UI tests;
- builds the Android ARM64 Release APK only after analysis and focused tests pass.

No iOS, macOS, Windows, Linux, Web or general integration-test suite was added. The standalone `markstream` test/analyzer steps remain excluded; `markstream` stays resolved as an application runtime dependency through root `flutter pub get`.

## Phase status

**Phase 2 — Conversational Extension Commands remains active.** No Phase 3 implementation was started. The failure is a missing-import issue in a selected regression test, not a change to the extension command implementation or its architecture.

## Validation and limitations

Performed in the preparation environment:

- Confirmed both missing declarations and their exact source imports.
- Confirmed the selected UI test names still match the Phase 2 runner.
- Confirmed the Android-only test manifest and CI scripts remain the active test scope.
- Confirmed the Android NDK/CMake installation and application dependency resolution succeeded in the supplied run.
- Applied the single formatter patch captured by CI.

The preparation environment does not contain Flutter or Dart SDK. Therefore Dart analysis, Flutter tests and Android ARM64 APK compilation have **not** been executed locally and are not claimed as passing. They remain the next GitHub Actions verification gates.

## Acceptance criteria before moving to Phase 3

1. `dart analyze --fatal-infos` passes for production `lib`, the ten Phase 2 manifest files and the selected UI test file.
2. The ten focused Phase 2 regression files pass.
3. The two selected Android chat UI regressions pass.
4. The Android ARM64 Release APK is generated, non-empty and uploaded with its SHA-256 checksum.
5. The user verifies conversational Skill installation/progress on an Android device.

Phase 3 remains blocked until these checks are complete.
