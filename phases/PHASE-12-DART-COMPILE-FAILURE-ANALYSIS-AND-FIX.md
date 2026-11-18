# KELIVO — Dart compile failure analysis and patch

**Build run:** `42647272907`  
**Commit tested:** `a52aa782aef5`  
**Target:** Android `arm64-v8a`, Release, Flutter `3.47.6`, Dart `3.13.5`  
**Result:** Pub and pre-build checks passed; Dart kernel compilation failed after the Android build started.

## What passed

- Android-only / Release source audit
- Flutter and Dart setup
- `flutter pub get` (23 seconds)
- Arabic ARB key and placeholder parity
- `flutter gen-l10n`
- Java 17 setup
- Android NDK `28.2.13676358` and CMake `3.22.1` setup

The Android ARM64 build ran for 4m53s and failed at `:app:compileFlutterBuildRelease` during `kernel_snapshot_program`. APK packaging and artifact upload were correctly skipped. Host-side Flutter tests were intentionally skipped and were not the cause.

## Root causes fixed in source

| Area | Compiler symptom | Correction |
|---|---|---|
| Runtime profile shell wrapper | Dart attempted to interpolate shell `$?` and `$()` | Preserved shell expansion literally while retaining Dart path/limit interpolation |
| Runtime profile setup | Dart attempted to interpolate shell `$?` | Escaped the shell status expansion |
| Video-provider JSON schema | `$` in the regex pattern was treated as Dart interpolation | Changed the pattern to a raw Dart string |
| Package-manager command generation | `$PATH`, `$LOCK_PATH`, `$LOCK_DIR` were parsed as Dart fields | Preserved these as shell variables |
| Package-manager detection | Declaration parsed as a function; script `$command_name` interpolated | Changed to a getter and raw shell script |
| Package-manager adapters | Concrete classes did not satisfy `base` constraints or inherit a default interface body | Marked concrete adapters `final` and implemented the default `prepareInstallCommand` in `_Adapter` |
| Calculator | `GrammarDefinition.build` called with an unsupported type argument | Uses `build()` and explicitly types the result as `Parser<_Value>` |
| Hybrid workflow | `RegExp` declared `const` | Changed to `final` |
| Video engine | Untyped metadata path passed to `path.join`; static symlink API did not exist | Validates/promotes `packagePath` to `String` and resolves links on `File`/`Directory` instances |
| Workspace video services | `WorkspaceZone` library was not imported | Added explicit `workspace_runtime.dart` imports |
| Hybrid workflow route | A saved route `Map` was accessed as a typed object; saved camelCase did not match request snake_case | Added `HybridSceneRoute.fromSavedJson` and return the typed model from `_routeFor` |
| Credentials page | Dynamic conditional used inside `const InputDecoration` | Removed the invalid `const` |
| Video-engine manifest | `$key_invalid` was parsed as a missing Dart variable | Corrected interpolation to `${key}_invalid` |
| Video-provider manifest | Nullable fields were assigned to `List<String>` | Filters nullable fields with `whereType<String>()` |

## Regression tests added

- Package-manager detection script must retain shell `$command_name` and `$(uname -m)`.
- Runtime wrapper must retain shell `$?`, command substitution and final exit status.
- A persisted camelCase hybrid route must restore to the same typed route model.

These tests were added to the source test suite but were not run in this environment. They are not added to the Android Release workflow; native host test hooks are intentionally kept out of that job.

## Files changed

- `lib/core/services/runtime_profiles/runtime_profile_models.dart`
- `lib/core/services/runtime_profiles/runtime_profile_service.dart`
- `lib/core/services/video_providers/video_provider_tools.dart`
- `lib/core/services/packages/package_manager_adapters.dart`
- `lib/core/services/packages/package_manager_service.dart`
- `lib/features/home/services/calculator_service.dart`
- `lib/core/services/video_hybrid/hybrid_workflow_spec.dart`
- `lib/core/services/video_hybrid/video_hybrid_workflow_service.dart`
- `lib/core/services/video_engines/video_engine_service.dart`
- `lib/core/services/video_engines/video_engine_manifest.dart`
- `lib/core/services/video_production/video_production_service.dart`
- `lib/core/services/video_providers/video_provider_connector_service.dart`
- `lib/core/services/video_providers/video_provider_manifest.dart`
- `lib/features/workspace/pages/video_provider_credentials_page.dart`
- Three focused test files under `test/core/services/`.
- `phases/PHASE-12-IMPLEMENTATION-REPORT.md`.

## Validation limitations

The local editing environment does not contain Flutter/Dart and outbound access to the Dart archive is unavailable. Therefore the following have **not** been claimed as passed: `dart format`, `dart analyze`, Flutter tests, Kotlin/Gradle compilation, ARM64 APK generation, APK packaging or device validation. The Pub lockfile was not manually edited; Pub in CI remains responsible for the resolved versions and hosted checksums.

The build log also contains future-compatibility warnings for Gradle 8.14, AGP 8.12.1 and Kotlin 2.2.20, an Android plugin compile-SDK sentinel warning, and a retracted transitive `jni_flutter 1.0.4` notice. None caused the current Dart kernel failure. They are retained as follow-up review items instead of changing the Android toolchain and dependency graph during an unrelated source compile fix. In particular, do not set `compileSdk` to `2147483647` based on that warning.

**Phase 12 is still pending.** Require successful formatting/analysis and a complete ARM64 Release APK before acceptance; then validate the affected shell, route, package-manager, clipboard and secure-storage flows on device.

## Follow-up source consistency review

The typed-route migration was completed through all `run_scene`, `poll_scene` and `download_scene` call sites. Those paths now use `HybridSceneRoute.mode`, `.providerId`, `.model` and `.engineId` instead of continuing to index the result as a `Map`. The saved-route adapter accepts both camelCase persisted fields and the older/request-style snake_case fields, and `_routeFor` can locate either representation. A second focused regression case covers the legacy snake_case form.

This follow-up prevents the first route conversion from simply moving the compiler failure to the next statements and also protects existing workflow records during migration.

## Verification performed after patching

- Arabic localization parity: passed (4,696 messages; 4,578 Arabic translations; 118 English fallbacks).
- Android-only and Release-hardening audits: passed.
- YAML syntax: passed for 34 YAML/YML files.
- Shell syntax: passed for 34 shell scripts.
- Manual targeted source assertions: passed for the reported compiler-error patterns and the corresponding replacements.
- Full ZIP integrity and required-file checks: performed on the delivered archive.

Flutter/Dart formatting, semantic analysis, the newly added focused Flutter tests, and a second ARM64 build remain unexecuted in this patching environment. No claim of successful compilation or APK generation is made.
