# PHASE 2 — Second CI Failure Analysis and Correction

**Scope:** Resolve the Dart analysis failures reported after the first formatter/parser correction.

**Observed workflow run:** `42331768963`  
**Commit tested:** `f6c9897d3869de12202897dd62c987b5095d50ad`  
**Event:** `push` on `main`  
**Build mode:** `release`

## 1. Actual result

The previous syntax issue in `extension_command_tools.dart` was fixed. In this run, dependency resolution, Dart formatting, localization generation, and the untranslated-message check all passed. The first failing stage was:

`Dart analyze application sources and tests`

The analyzer returned exit code `3` with seven errors. As a consequence, unit tests and Android ARM64 APK compilation were skipped. No APK was produced in this run.

## 2. Seven analyzer errors and corrections

### A. Obsolete iOS storage integration test

`integration_test/data_recovery_storage_test.dart` referenced the removed `AppDirectories.privateDataDirectoryName` getter and asserted iOS-specific Documents/Application Support directory behavior. The test itself was explicitly skipped unless the host was iOS.

**Correction:** Removed this iOS-only integration executable from the Android-only project. Platform-neutral storage/recovery unit and regression tests remain in `test/`.

### B. GenUI WebKit/Android integration adapter

`integration_test/genui_web_sandbox_test.dart` referenced a missing `support/genui_web_navigation_audit.dart`; the two reported undefined functions were `GenUiAuditedAndroid` and `GenUiAuditedWebKit`. The old adapter file had been removed during Android-only cleanup, and the test still contained a WebKit branch.

**Correction:** Restored an Android-only `GenUiAuditedAndroid` adapter using `webview_flutter_android`. Simplified the real-engine integration test to use Android WebView only, removed the WebKit implementation branch and iOS/macOS-specific test setup, and retained the Android navigation/security assertions.

### C. Stale desktop branch in an Android UI test

`test/features/home/pages/home_selection_back_test.dart` retained desktop-only drag/window/hotkey assertions. One assertion referenced an undefined `windowCalls` variable.

**Correction:** Narrowed the test variant to Android, removed the non-Android window/hotkey branches and their imports, and retained phone/tablet layout, drawer, message selection, export, and Android back-navigation coverage.

### D. `FakeSkillsService` did not implement the expanded service API

`test/features/workspace/skills/skills_test_fakes.dart` implemented the old `SkillsService` contract. The production service had since gained directory import, source inspection, GitHub inspection/search/update, rollback, installed-skill search, markdown reading, and rollback availability methods. Its `importFromFile` override also lacked the new optional progress and cancellation parameters.

**Correction:** Updated the fake to match the current public signatures. Added lightweight local Markdown/directory behavior and explicit unsupported-operation results for remote operations that are not exercised by these UI fakes. Implemented local search, markdown reading, and `hasRollback` behavior.

## 3. Additional analyzer diagnostics cleaned up

The previous report also showed warnings/infos. This correction:

- Added `await` around serialized mutations inside `try` blocks in `SkillsService`, so asynchronous failures are observed by surrounding error handlers.
- Removed unused `path_provider` import from the Android Mermaid bridge stub.
- Removed unused `dart:convert` import from the extension service test.
- Removed the stale Windows key-event helper import from an Android chat-input test.
- Removed unnecessary `dart:typed_data` and Flutter foundation imports where Flutter's existing imports already expose the symbols.
- Removed redundant direct imports of Skill symbols already exported by `SkillsService`.
- Resolved provider dependencies before asynchronous permission authorization in `ToolHandlerService`, avoiding `BuildContext` access across async gaps.

The next analyzer run must confirm that no new warning/info remains under `dart analyze --fatal-infos`.

## 4. Validation performed in the preparation environment

- Android-only audit passed, including ARM64 ABI validation and all four PRoot library checksum checks.
- Both GitHub Actions workflow YAML files parsed successfully.
- `bash -n` passed for every `.github/scripts/*.sh` helper.
- Verified there are no references to the removed `privateDataDirectoryName` getter in integration tests.
- Verified the Android GenUI integration adapter exists and the WebKit adapter is no longer referenced.
- Verified the stale desktop `windowCalls` assertion is removed.
- Verified the iOS-only storage integration executable is removed.
- ZIP packaging and CRC integrity must be checked on the final archive before delivery.

## 5. Not executed locally

The preparation environment does not contain Flutter or Dart SDK. Therefore this correction has not been validated by an actual Dart analyzer, Flutter test runner, Android Gradle build, or device install. The next GitHub Actions run is required to verify:

1. `dart format` on all tracked Dart sources.
2. `dart analyze --fatal-infos lib test integration_test`.
3. `flutter test`.
4. Markstream analysis and tests.
5. Android ARM64 Release APK build and artifact upload.

Do not mark Phase 2 build acceptance complete until these GitHub checks pass and the APK installs and opens on the Android device.

## 6. Files changed by this correction

- `lib/core/services/skills/skills_service.dart`
- `lib/features/home/services/tool_handler_service.dart`
- `lib/shared/widgets/mermaid_bridge_stub.dart`
- `lib/core/services/extensions/conversational_extension_service.dart`
- `lib/main.dart`
- `test/features/workspace/skills/skills_test_fakes.dart`
- `test/core/services/extensions/conversational_extension_service_test.dart`
- `test/features/home/pages/home_selection_back_test.dart`
- `test/features/home/widgets/chat_input_bar_attachment_cleanup_test.dart`
- `test/features/chat/widgets/workspace_tool_ui_test.dart`
- `integration_test/genui_web_sandbox_test.dart`
- `integration_test/support/genui_web_navigation_audit.dart` (Android-only)
- `integration_test/data_recovery_storage_test.dart` (removed; iOS-only)
- `phases/PHASE-02-CI-SECOND-FAILURE-ANALYSIS-AND-FIX.md`
- `phases/PHASE-02-IMPLEMENTATION-REPORT.md`
- `phases/README.md`

## 7. Next action

Commit the corrected project. The push trigger will start the Android workflow automatically. Review the new `KELIVO_BUILD_REPORT.md` and raw logs. Do not begin Phase 3 until analysis, tests, markstream checks, and Android ARM64 Release all pass.
