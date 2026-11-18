# Phase 12 — Dependency Solver Repair and Gated Android CI

**Status:** Source/workflow correction prepared. GitHub Actions must rerun to verify Pub resolution, the two focused tests, and ARM64 APK compilation.

## Latest failure diagnosis

The supplied build report for run `42535447340` (commit `5126e9ffe4ebf955553bc245cdad6bb942f3f519`) passed checkout, Android-only audit, Java/Flutter setup, toolchain reporting, and installation of Android NDK/CMake. It stopped at `flutter pub get`; no localization generation, Flutter tests, APK build, or packaging began.

The Pub solver identified this incompatible dependency graph:

- `package_info_plus 8.3.1` requires `win32 ^5.5.3`.
- `share_plus 13.3.1` requires `win32 ^6.0.1`.
- `flutter_secure_storage_windows 4.2.2` also requires the Win32 6.x line.
- `file_picker` has already been raised to `^12.3.0`, which is on the Win32 6-compatible line.

The previous change that upgraded `share_plus` did not complete the graph migration because `package_info_plus` remained pinned to `^8.3.1`.

## Dependency correction

- Updated `package_info_plus` from `^8.3.1` to `^10.2.2`.
- `package_info_plus 10.2.2` uses the Win32 6.x dependency line and retains the `PackageInfo.fromPlatform()` API used by KELIVO.
- Its published requirements are Flutter >=3.38.1 and Dart >=3.10.0, with Java 17, Kotlin 2.2.0, AGP >=8.12.1 and Gradle >=8.13. KELIVO's pinned toolchain (Flutter 3.47.6 / Dart 3.13.5, Java 17, Kotlin 2.2.20, AGP 8.12.1 and Gradle 8.14) satisfies those published minimums.
- `pubspec.lock` is intentionally left for Pub to regenerate from the corrected direct constraints. CI uses normal `flutter pub get` (not `--enforce-lockfile`), so Pub will resolve and write the compatible graph in the runner. No successful solver run is claimed in this preparation environment because Flutter/Dart SDK is unavailable here.

## Build/test sequence and gating

The Android job is explicitly sequential and dependency-gated:

1. Checkout and Android-only/release-hardening audit.
2. Set up Flutter 3.47.6 and record Flutter/Dart/Android SDK versions.
3. `flutter pub get` — all dependency-backed stages wait for success.
4. Arabic ARB key/placeholder parity check.
5. `flutter gen-l10n` — generated localization files must exist before tests.
6. Exactly two focused Flutter tests: Arabic RTL rendering and persisted Arabic locale restore.
7. Set up Java 17 only after the tests pass, because Pub, l10n generation and host-side Flutter tests do not require the Android JDK.
8. Install pinned Android NDK/CMake only after the focused tests pass. These SDK components are needed for native APK compilation, not for Pub resolution or host-side localization tests.
9. Build Android ARM64 APK.
10. Package the APK and compute its SHA-256; upload only when packaging succeeds.

Every dependent step uses an explicit `if: success()` gate. A failure prevents all later work from starting. A new outcome recorder writes `skipped` entries for gated stages that GitHub did not run, so the build report distinguishes "not started" from "failed". Tests are not run before dependency resolution and localization generation, and no Phase regression or broad unrelated test suites run automatically.

A separate manual localization workflow is not present. There is one active Android build workflow; the old Phase test runner scripts are retained as source/history but are not referenced by the active CI and therefore add no build time.

## Packaging

The complete project is delivered inside one top-level `KELIVO/` directory within the ZIP archive.

## Not yet verified

No Flutter/Dart SDK is installed in the preparation environment. Therefore the new Pub dependency graph, regenerated lockfile, `flutter gen-l10n`, the two focused Flutter tests, and Android ARM64 compilation must be confirmed by GitHub Actions. Static Android-only audit, Arabic ARB parity, Bash syntax and workflow YAML parsing are run locally.

## Latest failure — XML / PetitParser solver conflict (run 42539987598)

The next CI attempt passed Android-only/release-hardening audit and installed the toolchain, then stopped at `flutter pub get`. The resolver showed that `file_picker 12.3.0` brings `file_picker_linux` / `dbus`, whose dependency graph requires PetitParser 7.x or XML 7.x, while KELIVO still directly constrained `xml ^6.5.0` and `petitparser ^6.1.0`.

The compatible correction is constrained by the local path dependency `dependencies/vector_graphics_compiler`, whose manifest allows `xml >=6.3.0 <=7.0.1`:

- Pin `xml: 7.0.1` (do not move to XML 7.1.x while the local compiler package retains its upper bound).
- Pin `petitparser: 7.0.2`, satisfying XML 7.0.1 and the DBus/file-picker Linux platform dependency ranges while staying on the known 7.0.x API line.
- Existing KELIVO XML usage relies on `XmlDocument.parse`, event parsing, DOM traversal and namespace helpers. XML 7.0.1 retains these entry points; namespace arguments are deprecated but remain available in this version.
- Existing PetitParser usage relies on grammar/parser combinators (`Parser`, `GrammarDefinition`, `seq*`, `map*`, `parse`, `Success` and `Failure`), available in the 7.0.x API.

## CI order and report correction

The runner already gates each dependent command with `if: success()` and sequences: Pub resolution → ARB parity → `flutter gen-l10n` → the two Arabic/RTL test files → NDK/CMake installation → ARM64 build → package → upload. The prior Markdown report displayed a misleading order because its report-generator sort map still referenced an older workflow and placed NDK before Pub and localization checks after APK upload. The report generator now uses the current canonical sequence and the current build-job name, so skipped steps are displayed in their true pipeline position.

The Android-only audit now checks that required step IDs appear in the required order and have explicit `success()` gates. The APK artifact upload also has an explicit gate. A Pub resolution failure must therefore mark later stages as `SKIPPED`, never as tests that started or failed.

## Verification boundary

Static verification can confirm the constraints are compatible with the reported resolver requirements and the local `vector_graphics_compiler` upper bound. The actual Pub solve, regenerated lockfile, focused Flutter tests and Android ARM64 build still require the pinned Flutter 3.47.6 CI runner; no successful build is claimed until that run completes.



## Latest supplied failure — Syncfusion / XML conflict (2026-11-09)

The supplied Android ARM64 Release run `42544471678` (commit `e1a753f9325e`) passed checkout, Android-only/release-hardening audit, Java/Flutter setup and toolchain reporting. It stopped at `flutter pub get`; localization checks, focused tests, NDK/CMake installation and APK compilation were correctly skipped. The solver reported:

- `syncfusion_flutter_pdf ^31.2.5` resolves only within the 31.x line, whose releases depend on `xml ^6.5.0`.
- KELIVO directly pins `xml 7.0.1` because the local `dependencies/vector_graphics_compiler` manifest permits XML only in `>=6.3.0 <=7.0.1`.
- The constraints cannot intersect. This was not an Android compiler, NDK, Java or Dart source failure; none of those later stages started.

### Applied dependency correction

- Aligned `syncfusion_flutter_core`, `syncfusion_flutter_sliders` and `syncfusion_flutter_pdf` to `^33.2.13+1`. Syncfusion's 33.2.13+1 PDF release explicitly updates its XML dependency to 7.0.1; the three Syncfusion packages are kept on one release line rather than mixing their APIs/core dependency versions.
- Kept `xml: 7.0.1` exact: the local vector compiler's upper bound is 7.0.1, so raising XML to 7.1.x would create a separate path-package conflict.
- Kept `petitparser: 7.0.2`, which was added for the XML 7 / file-picker federated-platform dependency graph. No unrelated XML or parser source code was rewritten.
- Removed the unused direct `reorderable_grid_view` dependency after a repository-wide Dart import/reference scan found no code use; the visible reorderable interfaces use Flutter's built-in reorderable list widgets. The stale comment describing the removed package was removed as well.

### Cross-check of the other previously adjusted packages

- `package_info_plus ^10.2.2` and `share_plus ^13.3.1` are on the Win32 6-compatible line. Their published Android requirements (Java 17, Kotlin 2.2.0, AGP 8.12.1 and Gradle 8.13 or newer) are met by this project: Java 17, Kotlin 2.2.20, AGP 8.12.1 and Gradle 8.14.
- `file_picker ^12.3.0` is handled through `lib/shared/utils/file_picker_compat.dart`: the wrapper uses the v12 static `pickFile`/`pickFiles` API, lazy `readAsBytes`, `lengthSync`, and the URI returned by `saveFile`, while preserving the app's existing result abstraction and test doubles. Application call sites use this wrapper rather than importing the plugin directly.
- `flutter_secure_storage ^11.2.0` is used through its ordinary `FlutterSecureStorage` read/write API. Its Android implementation requires API 24 or newer; the application inherits the Flutter toolchain's Android minimum SDK rather than hard-coding a lower API. Note that v11 removed legacy cipher algorithms: releases upgrading data created before the v10 migration path must follow the plugin's migration guidance; this archive does not claim to validate previously installed secure-storage data on a real device.
- The root and local package SDK constraints are internally consistent with the pinned Flutter 3.47.6 / Dart 3.13.5 toolchain. Android Gradle/NDK/CMake settings were not changed because the current failure occurs before Gradle is invoked.

### Lockfile and verification boundary

`pubspec.lock` in the supplied archive predates the current manifest edits: it still locks `package_info_plus 8.3.1`, `file_picker 10.3.10`, `share_plus 12.0.2`, `xml 6.5.0`, `petitparser 6.1.0` and Syncfusion 31.2.18, and it does not contain the newly declared `flutter_secure_storage` package. It is therefore not evidence of the current graph. It was deliberately not hand-edited: hosted-package checksums and the complete transitive graph must be regenerated by the real Pub solver with `flutter pub get` on the pinned Flutter runner.

Static source/manifest review is complete for this correction, but no successful Pub solve, Dart analysis, Flutter tests, Gradle build or APK is claimed here because this preparation environment has no Flutter/Dart SDK or Android build toolchain. The next GitHub Actions run must confirm the complete solver graph first, then pass the ARM64 Release build. Host-side Flutter tests are not part of the Android Release workflow because they can trigger Linux desktop native-asset hooks for dependencies that are only needed at runtime on Android. Any subsequent solver/compiler/build failure must be diagnosed from its full new log rather than assumed fixed by this XML correction.

### Static verification after the correction (2026-11-09)

- Android-only audit passed, including the new invariant that the three Syncfusion modules remain aligned on `^33.2.13+1`, XML remains exactly `7.0.1`, PetitParser remains `7.0.2`, and the unused reorderable package is not reintroduced.
- Release-hardening audit passed: ARM64-only packaging policy, backup/signing exclusions, secure credential-store wiring, resource telemetry and explicit workflow permissions are intact.
- Arabic ARB parity passed for all 4,696 messages and placeholders (4,578 reviewed Arabic translations; 97.49% coverage).
- Every root/local `pubspec.yaml` and both GitHub Actions workflow YAML files parse successfully; all shell scripts pass `bash -n`.
- A source import sweep across `lib`, `test` and `integration_test` found no other unused direct runtime dependency. Developer tools and platform-interface packages remain declared intentionally.
- These are source/static checks only. The stale lockfile is expected to change only after a real Pub solve; no Flutter/Dart/Gradle/APK pass is claimed.

## Latest dependency solver follow-up (2026-11-09, run 42551191165)

The new report failed at Pub resolution only. `super_native_extensions 0.9.1` pins `device_info_plus` below 12, which resolves to Win32 5; `package_info_plus 10.2.2` requires Win32 6. The correction pairs `super_clipboard` and `super_native_extensions` at `0.10.0-dev.2`, and moves the test-only direct `irondash_message_channel` constraint to `^0.8.0-dev.0`. This is an explicit prerelease alignment (the currently published stable remains 0.9.1); the package page labels this API early-stage/experimental. Validate the next Pub solve and Android build, then exercise paste/copy/image clipboard on a real Android device before acceptance.

The five package constraints requiring the Win32 6 line remain aligned: file_picker 12.3, secure storage 11.2, package_info_plus 10.2, share_plus 13.3 and wakelock_plus 1.8. Syncfusion remains aligned on 33.2.13+1 with XML 7.0.1 and PetitParser 7.0.2. Android minSdk is now at least 24 because secure storage 11 raised its minimum to API 24. The manifest includes super_clipboard's required DataProvider. Do not add a separate Rust toolchain setup action: `super_native_extensions 0.10.0-dev.2` uses a Dart build hook that selects and installs the pinned Rust toolchain when native assets are requested. The Android build still requires the pinned NDK/CMake installation.

The active Android Release workflow does not invoke `flutter test`. The two focused RTL and locale persistence tests remain in the repository and in an optional host-test runner, but running them through the root package's `flutter test` selects Linux (`x86_64-unknown-linux-gnu`) as the native-assets target. This triggers the clipboard package's Linux Rust backend and GTK/GLib build dependencies, although the product target is Android. Installing GTK/Rust desktop dependencies solely to run those tests would add time and irrelevant desktop toolchain requirements to the Android APK pipeline. Instead, Release CI retains ARB key/placeholder parity and `flutter gen-l10n`, then proceeds to the Android ARM64 build, which is the executable source/native compilation gate for the target platform. Historical tests remain source-only; no whole-repository `flutter test` or `dart analyze` runs.

Run 42636605500 confirms the correction path: Pub resolved successfully, ARB parity passed, and generation passed; the only failure was the Linux host native-assets hook before either selected assertion ran. The test runner spent 50 seconds attempting to install Rust 1.97.1 and compile GTK/GLib crates, then failed because `gobject-2.0.pc` and `glib-2.0.pc` were absent. Java, NDK/CMake and APK build were never reached. The updated workflow records these host tests as intentionally deferred and continues to Android build after localization generation.

Static audit, release-hardening audit and ARB parity passed in the previous runner. This archive's workflow-only correction has passed source-level validation; the actual ARM64 native hook and APK build remain unverified until the next GitHub Actions run.


## Actual CI failure follow-up — 2026-11-09 (run 42636605500)

The latest uploaded reports show that Pub dependency resolution is now successful: `dbus 0.7.15`, `device_info_plus 13.3.0`, `win32 6.4.0`, `xml 7.0.1`, `petitparser 7.0.2`, and all three Syncfusion modules resolved together. ARB parity also passed for 4,696 messages/placeholders (4,578 reviewed Arabic translations; 118 English fallbacks), and `flutter gen-l10n` completed.

The failure occurred at `flutter test`, before either named localization assertion executed. Flutter's test runner selected host Linux `x86_64-unknown-linux-gnu`, then the `super_native_extensions 0.10.0-dev.2` build hook attempted to compile its Rust Linux backend. Cargo failed because the runner does not have `gobject-2.0.pc` or `glib-2.0.pc` (`pkg-config` could not find `gobject-2.0` / `glib-2.0`). This is a host-test toolchain failure, not a failing Arabic locale assertion or an Android source compile error.

CI correction: the Android Release workflow now records the two host-side Flutter tests as intentionally deferred rather than executing them. Their test files and the optional local runner are preserved. The workflow continues to retain the ARB key/placeholder parity check and generated-localization step, then installs Java/NDK/CMake and builds the actual ARM64 Android target. This avoids adding Linux GTK development packages and compiling a desktop Rust backend to a mobile-only Release pipeline. The package hook remains active for the actual Android target; the next run must verify that Android-native Rust compilation and APK packaging both succeed.

No APK success is claimed from run 42636605500: the test-stage failure prevented Java, NDK/CMake installation and ARM64 compilation. Phase 12 remains pending until the next Android Release workflow produces the APK and the clipboard copy/paste/image paths are checked on an Android device.


## Later Phase 13 CI clarification — 2026-11-11 (run 42929627194)

The earlier Phase 12 decision to defer Flutter host tests remains historically correct for that Phase 12 workflow, but it does not mean GTK/GLib can be skipped once Phase 13 adds mandatory `flutter test` smoke gates. The run `42929627194` showed that the root package's resolved build-hook graph executes `super_native_extensions` for Linux even when the selected smoke files do not directly import the clipboard API. Its Rust host build requires `glib-2.0`, `gobject-2.0`, `gio-2.0` and `gtk+-3.0` development metadata. Phase 13 CI therefore prepares these packages on Ubuntu before all smoke modes; they are runner-only dependencies and are not bundled into Android. The standalone Native Asset smoke and broad test suites remain extended-only.
