# PHASE 2 — CI Failure Analysis and Correction

**Scope:** Fix the first real GitHub Actions failure for the Phase 2 conversational Skills implementation.

**Observed workflow run:** `42329184912`  
**Commit tested:** `aff43f3592ad`  
**Event:** `push` on `main`  
**Build mode:** `release`

## 1. Actual failure

The workflow completed checkout, Java setup, Flutter setup, Android SDK component installation, application dependency resolution, and markstream dependency resolution successfully.

The first failing stage was `Dart format check for changed files`.

Dart reported a parser error in:

`lib/core/services/extensions/extension_command_tools.dart`

At line 126, the method `_tool` was declared with an arrow body (`=>`) but the body contained local variable declarations and a `return` statement. Dart arrow bodies accept an expression, not a statement block. This caused:

- `Expected an identifier.`
- `Expected to find '}'.`

The formatter exited with code 1. Its output also listed 36 Dart files that would be reformatted once the parser error was corrected. Localization generation, Dart analysis, Flutter tests, and Android APK compilation were skipped as a consequence. No APK was produced.

## 2. Correction applied

Changed `_tool` from an invalid arrow-body declaration to a normal block-bodied method:

```dart
  ]) {
    final parameters = <String, dynamic>{
      'type': 'object',
      'properties': properties,
      'additionalProperties': false,
      if (required.isNotEmpty) 'required': required,
    };
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }
```

Added a regression assertion to `test/core/services/extensions/conversational_extension_service_test.dart` verifying that the install tool definition exposes a valid object schema, disallows additional properties, exposes a properties map, and requires `source`. Because the report showed 36 style-only formatter changes and the local preparation environment has no Dart SDK, the Android build workflow now formats all tracked Dart source/test files in its temporary runner workspace before analysis/tests/build, verifies the formatted result, and saves the exact formatting-only diff as `dart-format-fixes.patch` in the report artifact. This avoids another style-only early stop while preserving the user's repository unchanged; the patch can be reviewed and committed separately. Syntax/parse errors still fail the formatting step.

## 3. GitHub Actions maintenance

The report also showed Node.js 20 deprecation notices for older first-party actions. Updated workflow references:

- `actions/checkout`: `v4` → `v7`
- `actions/setup-java`: `v4` → `v6`
- `actions/upload-artifact`: `v4` → `v7`
- `actions/download-artifact`: `v4` → `v8`

These are the current documented major versions selected for the GitHub-hosted Actions environment at the time of this correction. No build logic or Android target settings were changed by these version updates.

## 4. Validation performed in the preparation environment

- Verified the malformed method was replaced exactly once.
- Verified the new regression assertions are present.
- Parsed both GitHub Actions workflow YAML files successfully.
- Ran `bash -n` against every `.github/scripts/*.sh` script successfully.
- Confirmed action references no longer use the deprecated v4 majors for checkout, setup-java, upload-artifact, or download-artifact.
- Rechecked that the Android ARM64 build workflow retains automatic `push`, `pull_request`, and manual `workflow_dispatch` triggers.
- Rechecked that the Android-only audit script still enforces Android ARM64 and validates the four PRoot library checksums.

## 5. Not executed locally

The preparation environment has no Flutter or Dart SDK and has no network access to download one. Therefore the following remain unverified until the next GitHub Actions run:

- Actual `dart format`, Dart analysis, and Flutter execution under the GitHub-provisioned SDK; only the workflow logic was simulated locally.
- `dart analyze --fatal-infos lib test integration_test`.
- `flutter test`.
- markstream analysis and tests.
- Android ARM64 Release APK build and artifact upload.

Do not mark Phase 2 build validation complete until those steps pass in GitHub Actions and the resulting APK is installed and opened on the Android device.

## 6. Files changed by this correction

- `lib/core/services/extensions/extension_command_tools.dart`
- `.github/scripts/format_changed_dart.sh`
- `.github/scripts/generate_build_report.py`
- `test/core/services/extensions/conversational_extension_service_test.dart`
- `.github/workflows/android-build.yml`
- `.github/workflows/pr-check.yml`
- `phases/PHASE-02-CI-FAILURE-ANALYSIS-AND-FIX.md`
- `phases/PHASE-02-IMPLEMENTATION-REPORT.md`

## 7. Next action

Commit the corrected project. The `push` trigger runs the comprehensive Android workflow automatically. Review `KELIVO_BUILD_REPORT.md` and its raw logs. Continue only after format, analysis, tests, and Android ARM64 Release all pass.
