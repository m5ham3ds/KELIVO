# PHASE 2 — CI Test Failure Analysis and Fix

## Source build report

- GitHub run: `42338655869`
- Repository / branch: `m5ham3ds/KELIVO` / `main`
- Tested commit: `266bce246010c7293361b57bacd9e0325d9b8429`
- Flutter: `3.47.6`; Java: `17`; Android target: `arm64-v8a`
- Dart format: **SUCCESS** (38 files were normalized in the CI workspace)
- Dart analyze: **SUCCESS** (`No issues found!`)
- Flutter application tests: **11,416 passed, 41 failed, 8 skipped**
- Failure stage: Flutter application test suite. Markstream checks and Android APK build were skipped after test failure.

## Failure breakdown

The 41 failures were not 41 unrelated application defects. They fell into two groups: tests still targeting native platforms deliberately removed from this Android-only distribution, and tests whose expectations or fixtures had not been updated for Phase 2's always-available conversational extension tools and managed Core Guidance.

### A. Removed or re-targeted platform-specific tests (28 failures)

1. `test/shared/widgets/mermaid_windows_bridge_test.dart` — 4 Windows/WebView2 tests removed because the Windows native bridge is not part of the Android app.
2. `test/features/browser/browser_page_test.dart` — 1 macOS titlebar/window-controls test removed.
3. `test/features/settings/search/settings_search_widgets_test.dart` — 1 desktop display-settings navigation test removed.
4. `test/features/intelligent_ui/web_widgets_test.dart` — 5 iOS/macOS native WebView lifecycle variants switched to `TargetPlatform.android`, so the existing lifecycle behavior is exercised for the only supported native target.
5. `test/features/intelligent_ui/web_controller_test.dart` — 1 macOS-only workaround for a platform background API removed; Android's normal initialization path remains covered by the main controller test.
6. `test/tool/macos_signing_test.dart` — 3 macOS certificate/signing tests removed.
7. `test/core/services/asr/system_asr_service_test.dart` — macOS plugin-channel and `macos/Runner/Info.plist` tests removed; replaced with an explicit Android ASR capability test.
8. `test/core/services/sandbox/ios_environment_native_test.dart` — 2 iOS profile/native environment tests removed.
9. `test/core/database/storage_recovery_regression_test.dart` — 5 tests relying on the old iOS split Documents/Library storage layout removed.
10. `test/core/database/ios_split_storage_test.dart` — 5 iOS-only split-storage migration/restore tests removed.

Of these 28 platform-related failures, 5 GenUI WebView tests were retained and redirected to Android; the other 23 obsolete platform-only test cases were removed. The Flutter test command itself remains enabled and is not being skipped.

### B. Phase 2 / application test contract corrections (13 failures)

- `test/features/browser/browser_page_test.dart`: address input and read-only label retain the same medium font weight at both collapsed and expanded endpoints.
- `test/features/browser/browser_bookmark_editor_test.dart`: the typography assertion now compares against `AppFontWeights.semibold`, which is intentionally platform-normalized, instead of requiring raw `FontWeight.w600`.
- `test/features/home/services/assistant_search_test.dart`: assertions now filter the web-search tools under test. Phase 2 extension-management tools are intentionally available in the common agent tool catalog even when an assistant has web search disabled.
- `test/features/home/services/memory_tools_test.dart` (2 tests): legacy memory assertions now filter the legacy memory tool subset from the unified tool catalog, and localized-description assertions inspect only those legacy memory definitions.
- `test/features/chat/widgets/workspace_tool_ui_test.dart` (2 tests): list output no longer duplicates the `Installed Skills` timeline title; the harness uses `ChangeNotifierProvider.value` for its externally-owned `ToolRunRegistry`, verifies the completed run remains registered as `succeeded`, and pumps the reattached status listener before checking the Completed state.
- `test/core/services/auth/chatgpt_model_sync_test.dart`: the current-version OAuth fixture now includes the model's synced session id, matching the production metadata written by catalog synchronization.
- `test/core/services/skills/skills_service_test.dart` (5 tests): failed/cancelled import cleanup assertions now exclude Kelivo-managed `.kelivo-core` guidance from the user-installed Skill area while still verifying that no partial Skill or import-staging directory remains.

## Source changes

### Runtime / UI

- `lib/features/browser/widgets/browser_controls.dart` — apply `AppFontWeights.medium` to both editable and read-only address text at compact and expanded sizes.
- `lib/core/services/extensions/conversational_extension_service.dart` — change the list tool's result heading to `Found N installed Skills.` so it does not duplicate the tool card label.
- `lib/features/chat/widgets/workspace_tool_ui.dart` — change the compact list-tool subtitle to `Show all Skills`, leaving `Installed Skills` as the single timeline title.
- `lib/features/chat/widgets/workspace_tool_ui.dart` — change the list-tool subtitle to `Show all Skills`, leaving the card title as the sole `Installed Skills` label.

### Tests / platform suite

- Updated the tests listed above to match the Android-only target and Phase 2's common extension-tool behavior.
- Removed only native-platform test files whose target implementations are intentionally absent from this Android-only app.

## Validation performed in the packaging environment

- Android-only audit passed: Android target, ARM64 ABI, and four PRoot library checksums verified.
- YAML syntax parsed: 34 files.
- JSON syntax parsed: 125 files.
- Dart import targets checked: 7,475 `package:Kelivo` references and 4,855 relative references across the first-party `lib`, `test`, and `integration_test` trees; no missing targets.
- All `.github/scripts/*.sh` files passed `bash -n`.
- No workflow/test references remain to the five deleted test files.
- Full project archive integrity and one-root-folder structure are checked during packaging.

## Validation not performed locally

The file-preparation environment has no Flutter or Dart SDK executable. Therefore Dart formatting, analyzer, Flutter tests, Markstream tests, and Android Release build have **not** been rerun locally after these edits. They must be confirmed by the next GitHub Actions run. The previous report is evidence for the original failure only; this report is a record of the fixes and static checks, not a claim that the next build has already passed.

## Expected next CI sequence

1. Dart formatting
2. Localization generation and untranslated-message check
3. Dart analyzer
4. Full Flutter application tests (not disabled)
5. Markstream analyzer and tests
6. Android ARM64 Release APK build
7. APK checksum/artifact upload and comprehensive Markdown build report


## Exact source change inventory

Added:
- `phases/PHASE-02-CI-TEST-FAILURE-ANALYSIS-AND-FIX.md` (this report).

Removed as native-target-only test files:
- `test/shared/widgets/mermaid_windows_bridge_test.dart`
- `test/tool/macos_signing_test.dart`
- `test/core/services/sandbox/ios_environment_native_test.dart`
- `test/core/database/storage_recovery_regression_test.dart`
- `test/core/database/ios_split_storage_test.dart`

Modified source and tests:
- `lib/core/services/extensions/conversational_extension_service.dart`
- `lib/features/chat/widgets/workspace_tool_ui.dart`
- `lib/features/browser/widgets/browser_controls.dart`
- `test/core/services/asr/system_asr_service_test.dart`
- `test/core/services/auth/chatgpt_model_sync_test.dart`
- `test/core/services/skills/skills_service_test.dart`
- `test/features/browser/browser_bookmark_editor_test.dart`
- `test/features/browser/browser_page_test.dart`
- `test/features/chat/widgets/workspace_tool_ui_test.dart`
- `test/features/home/services/assistant_search_test.dart`
- `test/features/home/services/memory_tools_test.dart`
- `test/features/intelligent_ui/web_controller_test.dart`
- `test/features/intelligent_ui/web_widgets_test.dart`
- `test/features/settings/search/settings_search_widgets_test.dart`

## Interpretation of remaining platform references

Some generic Flutter widget tests still use `TargetPlatform.iOS`, `macOS`, or `windows` to verify adaptive styling and cross-platform Flutter behavior. These are not native build targets, do not restore deleted platform projects, and did not cause this run's 41 failures. They remain unless a test depends on a removed native implementation. Android remains the sole application build target.
