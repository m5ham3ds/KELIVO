# Phase 12 — Implementation Report

**Status:** Source implementation prepared; not formally accepted. Android-only audit and static release-hardening audit are updated; release CI has been reduced to the two Arabic-specific tests and ARM64 build. Dart/Flutter analysis, Flutter tests, Kotlin/Gradle build, ARM64 APK and real-device measurements have not run in this preparation environment.

## Delivered changes

### Resource telemetry and render guard

- Added `lib/core/services/device_resources/device_resource_monitor.dart` with immutable telemetry snapshot parsing, Android method-channel access, unknown-state semantics and a configurable render guard.
- Added Android channel `app.device_resources` in `MainActivity.kt`.
- Native telemetry includes ActivityManager memory/low-memory status, Debug PSS, process CPU-time delta, StatFs storage, Android thermal status/headroom and battery temperature.
- Added the read-only `resource_preflight` action to the existing `video_engine` tool.
- Local rendering is guarded immediately before engine command execution. Severe measured memory/storage/thermal/battery conditions block a new render; moderate pressure returns warnings and recommendations.
- Both normal and hybrid production routes delegate to `VideoEngineService.render`, so they use the same guard without duplicate resource policy.

### Extension permissions and secret review

- Added `ExtensionPermissionPolicy`, a shared risk catalogue for Skills, engines and video providers.
- Added permission review metadata to engine/provider install and inspect results.
- Skill inspect and install summaries parse `metadata.kelivo.permissions` from `SKILL.md` and show risk/approval state; unknown or invalid declarations remain blocked and nothing is auto-granted.
- Existing provider credentials continue to use `flutter_secure_storage` with Workspace/provider-scoped opaque key names. Engine environment settings remain non-secret and secret-like keys are rejected.

### Release hardening and CI

- Added `.github/scripts/release_hardening_audit.sh` and wired it into `audit_android_only.sh`.
- The original broad Phase 7–12 regression manifest is retained as historical test material but is no longer run in the release build. The streamlined build runs only the Arabic RTL widget test and the persisted Arabic locale test, in addition to ARB key/placeholder parity and `flutter gen-l10n`.
- Excluded private Android signing properties and common keystore file types in `.gitignore`.
- Added resource-guard, parser and permission-policy tests, and extended the built-in tool catalog test for `resource_preflight`.
- Updated the phase master plan and active-phase index; Phase 12 is now the active source-preparation phase.

## Verification performed in the preparation environment

- Shell syntax checks are run for the Android audit and the focused Arabic localization test runner.
- Workflow YAML is parsed with PyYAML.
- The two Arabic localization tests are checked for existence and are the only Flutter tests invoked by release CI.
- The release-hardening static audit checks ARM64-only ABI, backup settings, signing-key exclusions, secure credential storage, resource channel registration, network-exception documentation and workflow permissions.
- Dart/Flutter and Android build executables are not available here. No `dart format`, `dart analyze`, `flutter test`, Kotlin compilation, Gradle build, APK packaging, phone installation or thermal load test is claimed.

## Known limitations

- The global cleartext compatibility flag remains enabled because current code uses HTTP mirrors and local callback flows, as well as imported/user-provided HTTP resources. This is documented as a residual security risk and a public-release review item.
- CI Release falls back to Android debug signing when `android/key.properties` is absent. The artifact is for internal testing, not public distribution. A private upload key and APK signature check are required for a public release.
- Telemetry is best-effort and manufacturer/API dependent. App-process CPU/PSS do not include the separate PRoot child processes. It can be unavailable, in which case the assessment is `unknown` and does not claim the device is safe.
- This phase blocks new local engine renders under critical measured conditions but does not pause/resume a running arbitrary engine or silently lower resolution.
- Full task checkpoint/resume after process death, true kernel-level sandboxing and runtime permission revocation remain outside this implementation.
- Phase 3–11 acceptance gates remain pending as previously recorded. Phase 2 stays accepted; no later phase is marked accepted without real CI/build/device evidence.


## Dependency compatibility follow-up — 2026-11-09

The latest supplied Release run `42544471678` reached Pub resolution and failed because Syncfusion PDF 31.x required XML 6.5 while KELIVO's local vector compiler capped XML at 7.0.1 and the root manifest pinned XML 7.0.1 for the file-picker platform dependency graph. The source correction aligns all three Syncfusion packages (`core`, `sliders`, `pdf`) to `^33.2.13+1`, whose PDF release notes explicitly move to XML 7.0.1. The exact XML and PetitParser pins remain constrained by the local compiler and federated file-picker graph. An unused `reorderable_grid_view` direct dependency was removed after a full source reference scan.

A cross-check also confirmed the app already uses the v12 file-picker compatibility wrapper and the Share Plus instance/ShareParams API expected by the declared package lines. The Java/Kotlin/AGP/Gradle versions satisfy the published Android requirements of `package_info_plus 10.2.2` and `share_plus 13.3.1`. `pubspec.lock` is known to be stale versus the current manifest and must be regenerated by `flutter pub get`; it was not fabricated manually. Pub resolution, Dart analysis, Flutter tests, Android ARM64 compilation and device validation remain unverified and Phase 12 is still not accepted.

### Follow-up static verification (2026-11-09)

The Android-only audit (including the new Syncfusion/XML guard), Release-hardening audit, Arabic ARB parity, all shell syntax checks, all root/local pubspec YAML parses and both workflow YAML parses pass. ARB validation covered 4,696 messages/placeholders with 97.49% reviewed Arabic coverage. A package-import sweep found no further unused direct runtime dependency after removing `reorderable_grid_view`. These checks do not replace the still-pending Pub solve, generated lockfile, Dart/Flutter tests or Android build.

## Latest dependency solver failure and CI reduction — 2026-11-09 (run 42551191165)

The newly supplied run `42551191165` (`e2b84a92a034`, Android ARM64 Release) failed exclusively in `flutter pub get`. The resolver output is explicit: `super_native_extensions 0.9.1` depends on `device_info_plus >=10.0.1 <12.0.0`; that device-info range is constrained to `win32 <6.0.0`, while `package_info_plus ^10.2.2` requires `win32 ^6.0.1`. The Android audit, Java, Flutter setup and version capture passed. The localization parity check, generated l10n, Flutter tests, NDK/CMake installation and APK build were all `SKIPPED`; none of those tests took time or failed in this run. Recorded runner durations were Java setup 6s, Flutter setup 34s, and Pub resolution 9s (the Flutter/Java caches were cold). The workflow now defers Java setup until after host-side localization checks, so dependency or test failures will avoid that 6-second setup.

### Dependency graph correction prepared

- Keep the Win32 6-compatible package family already used by the app: `file_picker ^12.3.0`, `flutter_secure_storage ^11.2.0`, `package_info_plus ^10.2.2`, `share_plus ^13.3.1` and the exact pin `wakelock_plus 1.8.0` (kept on the DBus 0.7.x-compatible release).
- Move `super_clipboard` and its paired `super_native_extensions` together to the exact `0.10.0-dev.2` release. That prerelease widens the `device_info_plus` compatibility range to include the 13.x line which resolves against Win32 6. The project's direct test-only `irondash_message_channel` constraint is also moved from `^0.7.0` to `^0.8.0-dev.0`, which is the channel dependency required by this prerelease.
- This is a deliberate prerelease dependency choice: Pub currently lists `0.9.1` as the latest stable for both clipboard packages and `0.10.0-dev.2` as prerelease. The published package page also describes the clipboard package as experimental. It is not represented as a stable upgrade; the app must exercise paste, copy and image clipboard flows on a real Android device before release acceptance. The next CI run must validate the actual Pub solve and ARM64 native build before Phase 12 is accepted.
- Keep Syncfusion Core, Sliders and PDF aligned on `^33.2.13+1`, XML pinned to `7.0.1`, and PetitParser pinned to `7.0.2`, as already required by the local vector-graphics compiler and the file-picker/DBus graph. Do not hand-edit `pubspec.lock`; Pub must regenerate the complete lock and hosted checksums.
- Set Android `minSdk` to `maxOf(flutter.minSdkVersion, 24)`: `flutter_secure_storage 11.0.0` raised its Android minimum to API 24. The super clipboard plugin also requires NDK and its README requires a content provider for image/custom clipboard writes; the matching `DataProvider` is now declared in the main manifest. The existing workflow installs the pinned NDK/CMake before APK compilation.
- Do not add a separate Rust setup action to CI. `super_native_extensions 0.10.0-dev.2` invokes a Dart build hook that installs its pinned Rust toolchain when native assets are required. The build hook selects assets for the current target; Android Release compilation still requires the pinned NDK/CMake.

### Test policy and build-time reduction

The active `.github/workflows/android-build.yml` is the only workflow in `.github/workflows`. It keeps the ARB key/placeholder parity check and `flutter gen-l10n`, but it does not run `flutter test` in the Android Release job. The two focused test files and their optional host runner remain in source. The latest run proves why: root-package `flutter test` executes native build hooks for the Linux test host, so `super_native_extensions` attempted to compile GTK/GLib Rust code which is unrelated to the Android product target. Avoiding the test command removes this 50-second host compilation attempt and avoids installing GTK development packages just for mobile CI. The whole-repository `flutter test` suite and `dart analyze` remain excluded. The Android ARM64 release build itself is kept as the executable source/native compile gate.

### Verification boundary

The updated Android-only/release-hardening audits and Arabic ARB parity script pass in the preparation environment; all shell scripts pass `bash -n`, the report generator passes Python bytecode compilation, and all root/local pubspec and workflow YAML documents parse. Flutter/Dart SDK and Android Gradle toolchain are unavailable here, so the new prerelease Pub solver result, regenerated lockfile, the two smoke tests and Release APK remain unverified. Do not mark Phase 12 accepted until the next full CI run passes those gates.


## Latest CI result — 2026-11-09 (run 42636605500, commit ecb4ffd33630)

- `flutter pub get` succeeded and resolved the previously conflicting package graph, including `dbus 0.7.15`, `device_info_plus 13.3.0`, `win32 6.4.0`, `xml 7.0.1`, `petitparser 7.0.2`, and Syncfusion Core/PDF/Sliders `33.2.15`.
- Arabic parity succeeded: 4,696 messages/placeholders, 4,578 reviewed Arabic translations (97.49%), and 118 English fallbacks.
- `flutter gen-l10n` succeeded.
- The only failing step was the host-side Flutter test command. It failed before test assertions because the Dart build hook for `super_native_extensions 0.10.0-dev.2` invoked Cargo for `x86_64-unknown-linux-gnu`; `gobject-2.0.pc` and `glib-2.0.pc` were missing from the GitHub runner. It spent 50 seconds compiling the Linux Rust dependency graph.
- The workflow now records the host-side tests as intentionally deferred; no GTK packages or desktop Rust build are added to the Android Release pipeline. The test files remain in source for a dedicated host environment.
- Java, Android NDK/CMake, ARM64 compilation and APK packaging did not run in the failed attempt. The Android-native asset hook and final APK therefore remain unverified. Phase 12 must remain pending until a subsequent workflow builds and packages the ARM64 APK and clipboard operations are checked on-device.


## Latest CI result — 2026-11-09 (run 42647272907, commit a52aa782aef5)

This run proves the dependency and CI-trim work reached the Android compile stage:

- Pub resolution succeeded in 23 seconds. The resolved graph includes `dbus 0.7.15`, `device_info_plus 13.3.0`, `win32 6.4.0`, `xml 7.0.1`, `petitparser 7.0.2`, and aligned Syncfusion Core/PDF/Sliders `33.2.15`.
- Arabic ARB parity and `flutter gen-l10n` both succeeded. The two host-side localization tests were intentionally skipped, as documented; no host Rust/GTK build was attempted.
- Java 17 and the pinned Android NDK/CMake setup succeeded.
- `flutter build apk --release --target-platform android-arm64` started and ran for 4m53s. It failed during Flutter's Dart `kernel_snapshot_program`, before APK packaging and upload. This is a source-compilation failure, not a Pub, Gradle wrapper, NDK installation or test failure.

### Dart compile errors and source corrections

The compiler reported errors in 14 Dart source files. The diagnostics cluster into root causes rather than dozens of independent defects:

1. Shell strings contained unescaped shell `$?`, `$()`, `$PATH`, `$LOCK_PATH`, `$LOCK_DIR` and `$command_name` sequences. Dart attempted to interpolate them as Dart variables. They are now emitted literally using raw strings or `${r'$'}` while keeping intended Dart interpolation (such as paths and numeric limits) intact.
2. `packageManagerDetectionScript` was written as a function-like declaration instead of a getter. It is now `String get ...`; the package-manager adapter base adds the missing inherited default for `prepareInstallCommand`, and concrete adapters extending the `base` classes now declare `final`.
3. The calculator called `GrammarDefinition.build` with an obsolete explicit type argument. PetitParser 7 exposes `build() -> Parser<R>` on `GrammarDefinition<R>`, so the call is now non-generic with an explicit `Parser<_Value>` result type.
4. Non-const `RegExp` and a non-constant `InputDecoration` were incorrectly declared `const`; both declarations are now runtime values.
5. Video engine metadata is narrowed to `String` before path operations, and symbolic-link resolution now uses the `File`/`Directory` instance API according to the filesystem entity type.
6. `VideoProductionService` and `VideoProviderConnectorService` used `WorkspaceZone` without importing the library that declares it; the imports are now explicit.
7. Hybrid workflow routes were stored in camelCase but the request parser accepts snake_case. The service treated a raw `Map` as a typed route. A dedicated `HybridSceneRoute.fromSavedJson` adapter now normalizes stored JSON and returns the typed route model.
8. Optional provider request-field paths are filtered with `whereType<String>()` before being collected as non-null strings.
9. The engine-manifest validation error now interpolates `${key}` correctly.

Focused regression tests were added for shell variable preservation in the package-manager script, shell exit-status/command-substitution preservation in runtime wrappers, and camelCase hybrid-route round trips. The existing test corpus was not deleted and Release CI remains trimmed; these focused tests are intended for a developer environment with Flutter/native host dependencies, not the Android-only release job.

### Remaining verification and non-causal warnings

The patching environment has no Flutter/Dart executable and cannot reach the Dart archive, so `dart format`, `dart analyze`, focused `flutter test`, and another ARM64 build were not run here. The lockfile was not manually fabricated; Pub successfully resolved the current graph in CI and remains the authority for its lock/checksums.

The Gradle 8.14, AGP 8.12.1 and Kotlin 2.2.20 messages are forward-compatibility warnings, not the failure in this run. The plugin compile-SDK warning also did not stop the build; do not set `compileSdk` to the reported `2147483647` sentinel. Keep those Android toolchain warnings as a separate compatibility follow-up after the Dart compile is clean. A retracted transitive `jni_flutter 1.0.4` is also visible in Pub output with `1.0.4+1` available; it did not cause this failure and should be assessed against the native build before changing the graph.

**Acceptance remains pending.** The next required gate is successful Dart formatting/analysis and ARM64 Release compilation, followed by APK packaging and real-device checks for package-manager operations, runtime shell execution, video route persistence, clipboard behavior and secure credentials. No phase acceptance is inferred from source edits alone.

## Dart kernel compilation follow-up — 2026-11-09 (run 42647272907)

The supplied run `42647272907` (`a52aa782aef5`) passed dependency resolution, Arabic localization parity, `flutter gen-l10n`, Java 17, and NDK/CMake installation. The Android ARM64 Release step then ran for 4m53s and failed at `:app:compileFlutterBuildRelease` during Dart `kernel_snapshot_program`; APK packaging/upload were skipped. The Linux host-side Flutter tests remained intentionally skipped and were not the cause.

The source patch addresses the compiler diagnostics across 14 Dart files: literal shell interpolation (`$?`, `$()`, `$PATH`, lock variables and package-manager variables), invalid top-level package-manager script declaration, base-class modifier/default-method issues, PetitParser 7 `build()` invocation, a non-const `RegExp`, metadata path promotion and filesystem instance symlink resolution, missing `WorkspaceZone` imports, a route Map/model mismatch, non-constant `InputDecoration`, manifest interpolation and nullable request-field paths.

The hybrid workflow repair now consistently returns a `HybridSceneRoute` from `_routeFor` and all three execution paths (`run_scene`, `poll_scene`, `download_scene`) use typed properties. Saved-route normalization supports both camelCase and legacy snake_case shapes, including route lookup by either scene-id key. Added focused regression tests cover package-manager shell expansion, runtime shell exit/substitution preservation, camelCase saved-route restoration and legacy snake_case route restoration. They remain source tests and are not added to Release CI.

Post-patch static checks passed: Arabic ARB parity (4,696 messages, 97.49% reviewed Arabic coverage), Android-only/Release hardening audits, 34 YAML/YML parses and `bash -n` for 34 shell scripts. The patching environment does not include Flutter/Dart, so `dart format`, `dart analyze`, Flutter tests and another Android ARM64 build were not run. Phase 12 remains pending until CI produces the ARM64 Release APK and the affected flows are exercised on-device.


## Post-build Skill management follow-up — Skill Packs and slash activation

The post-build device validation found that related YouTube Skills had been installed as separate entries with no pack-level refresh and no composer shortcut. A follow-up implementation now automatically groups Skills from the same GitHub/skills.sh repository while preserving each Agent Skill directory and `SKILL.md`. It adds manual packs, unique `/shortcut` values, member and pack ordering, one pack activation switch, per-chat selection, multi-pack leading slash commands and command-only activation for both existing and new chats. Newly detected packs are disabled by default so they are not injected into unrelated conversations. `skill_compose` remains responsible for progressive disclosure within the selected pack.

The Skills page now exposes Update all, Create pack and import actions; pack rows expose a single repository refresh when source metadata is valid. GitHub pack updates group members by repository/ref and reuse one archive download per group. Legacy remote Skills with missing provenance can connect a validated GitHub or skills.sh source from the list, detail actions or pack editor. Source replacement clears stale subpath/ref/revision metadata. The old per-Skill `setEnabled` API now delegates to the pack state when that Skill belongs to a pack.

Focused tests were updated for repository auto-grouping/update, source repair and stale metadata clearing, pack-state consistency, page actions, source-link UI and conversation pack selection. Static preparation checks passed: ARB parity (4,733 messages; 97.49% Arabic coverage), 34 YAML/YML parses, all ARB JSON parses, `bash -n` for 30 shell scripts, Android-only audit and Release hardening audit. The current environment has no Flutter/Dart SDK, so formatting, analysis, focused tests, localization generation and a new ARM64 APK build were not run. See [the detailed Skill Pack follow-up](PHASE-12-SKILL-PACKS-AND-SLASH-COMMANDS.md). Phase 12 remains pending the next GitHub Actions run and real-device verification.

## Skill packs and chat shortcuts follow-up (source prepared; CI acceptance pending)

The follow-up closes the gap identified during real Skill installation: repository-related Skills were exposed as independent global switches and legacy entries could not be refreshed. The implementation adds repository-detected and user-editable Skill Packs without merging the underlying `SKILL.md` directories, per-chat `/shortcut` selection (including multiple packs and first-message pending selection), pack/member ordering, one-unit pack activation, update-all and pack refresh, plus repairable GitHub/skills.sh provenance. Focused regression tests cover pack grouping/refresh, pack activation semantics, legacy source repair, Skills page actions and selecting a pack from the chat Skills picker. See [Phase 12 Skill Packs and Slash Commands](PHASE-12-SKILL-PACKS-AND-SLASH-COMMANDS.md).

The preparation container has no Dart/Flutter SDK. Static repository audits and localization checks passed, but Dart format/analyze, focused Flutter tests and a new Android ARM64 Release build remain mandatory before accepting this follow-up. The previous user-confirmed v1.3.4+84 release remains the build baseline, not proof that these new UI and conversation changes compile.
