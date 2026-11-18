# Phase 13E — Nested Skill bundle extractor callback correction

**Status:** Source correction prepared. GitHub Actions focused tests and Android ARM64 Release build must be rerun; this correction has not yet been accepted by CI.

## Failure analyzed

Supplied GitHub Actions run: `43290392273`  
Commit: `d421280139461733b0ff18664fecbaa43d450b41`  
Failing stage: `Run focused Phase 13E regression tests`  
First test file: `test/core/services/sandbox/environment_status_tool_test.dart`

Dart failed while loading the test library because `SkillsService` did not compile:

```text
lib/core/services/skills/skills_service.dart:378:36:
Error: The getter '_extractNestedSkillBundleArchive' isn't defined
for the type 'SkillsService'.
```

The test runner stopped at the first test file. This is a compile-time callback-name error, not a failure of Ubuntu, PRoot, ZIP/UNZIP inside Ubuntu, or the nested archive algorithm. Later Phase 13E tests, localization and Android ARM64 packaging were skipped.

## Root cause

The recent nested Skill ZIP importer in `SkillsService.importSkillsFromFile()` called:

```dart
compute(_extractNestedSkillBundleArchive, (...))
```

No member with that name exists in `SkillsService`.

The project already has the correct isolate adapter:

```dart
static Map<String, Object?> _extractNestedSkillBundle(
  (String, String) args,
) => extractNestedSkillBundleArchive(args);
```

The same adapter is already used by `inspectLocalSource()`, while the underlying top-level function `extractNestedSkillBundleArchive` is implemented in `skill_archive.dart`.

## Correction

- Replaced the undefined callback reference in the local import path with the existing `_extractNestedSkillBundle` static adapter.
- Did not create a duplicate extractor or change ZIP parsing, safety limits, nested bundle layout, shared package-resource handling, companion-file completeness checks, or install/rollback behavior.
- Added a Phase 13E Preflight contract check that verifies:
  - the invalid callback name is absent;
  - `importSkillsFromFile()` routes its nested-bundle fallback through `_extractNestedSkillBundle`;
  - the static adapter signature matches `(String, String)`;
  - the adapter delegates to `extractNestedSkillBundleArchive`;
  - the archive extractor is present with the expected callback signature.
- Kept the existing `skill_bundle_import_phase13e_test.dart` cases. In particular, the `SkillsService imports every compatible nested Skill atomically and preserves companion files` test exercises the previously broken import call path.

## Validation performed here

- Confirmed there was exactly one invalid callback reference in the source.
- Confirmed the valid static adapter and underlying top-level extractor already existed.
- Applied the single callback-name correction.
- Added a structural Preflight regression guard for this exact class of compile error.
- Checked source-level callback wiring and shell syntax in the revised Preflight script.
- Verified that historical Phase 13A–13D runners remain outside the active 13E CI lane.

## Not yet verified

This environment did not run Flutter/Dart tests or build an APK. The previous CI run failed before any Phase 13E test assertions executed. A fresh GitHub Actions run must still pass the focused Phase 13E suite, Arabic localization checks, and Android ARM64 Release build before this correction can be accepted.

## Scope preservation

No dependency versions, `pubspec.lock`, Android configuration, Runtime/PRoot behavior, manual-approval policy, file-upload behavior, or historical Phase 13A–13D test runners were changed.
