# Kelivo Android-only source audit

This archive is an Android-only Flutter application source package. The Android app, Kotlin/Java sources, Android resources, CMake/JNI integration, and the ARM64 PRoot runtime are retained.

## Removed targets and native payloads

- Removed the top-level iOS, Windows, Linux desktop, macOS, and Web Flutter runner projects.
- Removed nested iOS/macOS/Windows/Linux/Web native implementation directories and platform example/test projects from vendored packages.
- Removed the vendored iOS, macOS, and Windows `flutter_inappwebview` override packages and the Windows permission-handler override package. Android now uses the Android implementation override only.
- Removed Web-only Mermaid rendering and MCP Web transports. Mermaid and HTML preview use Android WebView.
- Removed WebKit-only intelligent UI setup, WebView2 preview code, Windows drag-and-drop integration, and tests that exercised removed desktop/Web targets.
- Removed desktop-only plugin dependencies that were no longer used by Android (`desktop_drop`, `screen_retriever`, `webview_windows`, `webview_flutter_wkwebview`, `bitsdojo_window`, `window_manager`, `tray_manager`, and `system_fonts`).
- Removed iOS/Linux/macOS/Windows Sherpa package overrides; kept the Android runtime pin.
- Removed Windows data-directory management, Windows clipboard-history patching, Linux title-bar integration, native window sizing/placement, system-tray controllers, and obsolete desktop shell pages.
- Replaced macOS/Windows window chrome hooks with Android-safe layout behavior; kept shared responsive Flutter panes and controls that Android screens still use.
- Removed generated `.dart_tool`, Gradle, build, CocoaPods, Xcode, and other cache directories, plus desktop-only documentation screenshots.

## Why some platform terms remain in Dart source

Flutter exposes a shared `TargetPlatform` enum and some shared widgets use Cupertino-styled controls or adaptive spacing. These are Dart/Flutter UI abstractions, not iOS native resources or additional build targets. A few shared layout helpers under `lib/desktop/` are imported by Android screens (menus, dialogs, panes, and editor components), so deleting them wholesale would remove Android UI functionality. The Android APK target and its native payload remain ARM64 Android only.

The Linux PRoot environment is intentional: it is a Linux userland executed *inside Android* to provide the app's Android workspace/shell feature. It is not a Linux desktop runner. Some generic Dart utilities retain defensive platform branches and historical performance snapshots may mention former targets; those are not native runner projects, installed plugin dependencies, or bundled platform payloads.

## PRoot runtime reduction

`dependencies/termux/proot-5.1.107.92.tar.xz` contains only the four ARM64 (`arm64-v8a`) shared libraries required by `android/app/build.gradle.kts`. The checksum manifest lists only these four libraries, and `tool/fetch_proot.sh` restores only those files.

## Build failure repair

The previous Actions step failed at `yes | sdkmanager --licenses`: after `sdkmanager` had accepted the licenses and closed its input, `yes` received SIGPIPE (`Broken pipe`). Since the script used `set -o pipefail`, the producer's expected SIGPIPE made the whole step fail. The workflow now disables `pipefail` only around that pipeline, captures `PIPESTATUS[1]` (the `sdkmanager` exit code), restores `pipefail`, and fails only when `sdkmanager` itself reports an error.

An Android-only audit script now runs before the toolchain setup. It checks for non-Android runner directories/native files, deleted desktop-only plugin imports/subsystems, validates the ARM64 ABI configuration, and verifies the included PRoot archive/checksums.

## Build configuration

- Flutter: 3.47.6
- Java: 17
- Android NDK: 28.2.13676358
- CMake: 3.22.1
- APK target ABI: `arm64-v8a` only
- No API keys or private release-signing key are needed for a test build. If `android/key.properties` is absent, the release variant is signed with the debug key so the APK can be installed for testing.

## Verification policy

The preflight audit must keep the Android-only target, ARM64 ABI, PRoot archive members/checksums, localization ARB parity, focused PHASE13E–13P regressions and release hardening checks. It must not disable the separately named complete Flutter validation gates.

The Android Release workflow runs:
- `flutter analyze --no-pub` across the complete Flutter source.
- `flutter test --no-pub --reporter expanded` across all unit and widget tests.
- `gradle --no-daemon -p android :app:testDebugUnitTest` across all Android JVM/Robolectric tests.
- Browser navigation, browser workspace, browser app and Skill lifecycle integration tests on an Android emulator for each push to `main`.
- The ARM64 Release APK build only after the required gates succeed.

The older standalone host-localization test stage remains deferred; the current build validates Arabic ARB key/placeholder parity and runs generated Flutter localization tests inside the complete Flutter suite.

The working container used for source editing does not include Flutter/Dart/Gradle. A source edit is not considered verified until the corresponding GitHub Actions checks complete; the APK must be confirmed from the new Actions artifact, not inferred from static checks.
