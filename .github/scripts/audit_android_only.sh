#!/usr/bin/env bash
# Fail early if a removed desktop/iOS/Web build target leaks back into this package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() {
  echo "ANDROID-ONLY AUDIT FAILED: $*" >&2
  exit 1
}

# Validate the checkout layout before any later grep/find checks can emit
# misleading secondary errors when the Android project folder was not pushed.
[[ -s 'pubspec.yaml' ]] || fail 'Flutter project root is incomplete: pubspec.yaml is missing'
[[ -s 'android/app/build.gradle.kts' ]] || fail 'required Android Gradle config is missing from the checked-out source tree: android/app/build.gradle.kts (restore and commit the android/ project directory)'
[[ -s 'android/app/src/main/AndroidManifest.xml' ]] || fail 'required Android app manifest is missing from the checked-out source tree'

for target in ios windows linux macos web; do
  [[ ! -e "$ROOT/$target" ]] || fail "top-level '$target' target still exists"
done

platform_dirs="$(find . -type d \( -iname ios -o -iname windows -o -iname linux -o -iname macos -o -iname web \) -not -path './.git/*' -print -quit)"
[[ -z "$platform_dirs" ]] || fail "non-Android platform directory remains: $platform_dirs"

native_files="$(find . -type f \( \
  -iname '*.swift' -o -iname '*.m' -o -iname '*.mm' -o -iname '*.plist' \
  -o -iname '*.entitlements' -o -iname '*.podspec' -o -iname '*.pbxproj' \
  -o -iname '*.xcscheme' -o -iname '*.xcworkspacedata' -o -iname '*.vcxproj' \
  -o -iname '*.sln' -o -iname '*.rc' -o -iname '*.ico' \
\) -not -path './android/*' -not -path './.git/*' -print -quit)"
[[ -z "$native_files" ]] || fail "non-Android native project file remains: $native_files"

for removed_package in \
  'dependencies/flutter_inappwebview_ios' \
  'dependencies/flutter_inappwebview_macos' \
  'dependencies/flutter_inappwebview_windows' \
  'dependencies/flutter-permission-handler/permission_handler_windows' \
  'dependencies/webview_windows' \
  'dependencies/tray_manager' \
  'lib/core/services/linux_window_service.dart' \
  'lib/core/services/storage/windows_data_directory.dart' \
  'lib/features/settings/widgets/windows_data_directory_tile.dart' \
  'lib/shared/widgets/windows_data_directory_startup.dart' \
  'lib/desktop/desktop_tray_controller.dart' \
  'lib/desktop/desktop_window_controller.dart' \
  'lib/desktop/windows_paste_fix.dart' \
  'lib/desktop/window_title_bar.dart'; do
  [[ ! -e "$removed_package" ]] || fail "removed platform package still exists: $removed_package"
done

if grep -Eq '(^|[[:space:]])(flutter_inappwebview_ios|flutter_inappwebview_macos|flutter_inappwebview_windows|permission_handler_windows|webview_windows|webview_flutter_wkwebview|desktop_drop|screen_retriever|bitsdojo_window|window_manager|tray_manager|system_fonts):' pubspec.yaml; then
  fail 'pubspec.yaml still declares a removed non-Android dependency'
fi
if grep -R -n -E "package:(bitsdojo_window|window_manager|tray_manager|system_fonts)/" lib test integration_test --include='*.dart' >/dev/null 2>&1; then
  fail 'Dart source still imports a removed desktop-only plugin'
fi

gradle_config='android/app/build.gradle.kts'
[[ -s "$gradle_config" ]] || fail "required Android Gradle config is missing from the checked-out source tree: $gradle_config (restore and commit the android/ project directory)"
[[ -s 'android/app/src/main/AndroidManifest.xml' ]] || fail 'required Android app manifest is missing from the checked-out source tree'
ndk_filter_block="$(grep -A 5 -E '^[[:space:]]*ndk[[:space:]]*\{' "$gradle_config" || true)"
grep -Fq 'abiFilters += listOf("arm64-v8a")' <<< "$ndk_filter_block" \
  || fail 'Android defaultConfig.ndk.abiFilters must restrict packaged native libraries to arm64-v8a'
if grep -E 'abiFilters.*(armeabi-v7a|x86|x86_64)' "$gradle_config" >/dev/null; then
  fail 'Gradle ABI filters still include a non-ARM64 architecture'
fi

archive='dependencies/termux/proot-5.1.107.92.tar.xz'
checksums='tool/proot_checksums.txt'
[[ -s "$archive" ]] || fail "PRoot archive missing: $archive"
[[ -s "$checksums" ]] || fail "PRoot checksum manifest missing: $checksums"

members="$(tar -tJf "$archive")"
[[ -n "$members" ]] || fail 'PRoot archive is empty'
while IFS= read -r member; do
  [[ "$member" == arm64-v8a/*.so ]] || fail "unexpected PRoot archive member: $member"
done <<< "$members"

member_count="$(printf '%s\n' "$members" | wc -l | tr -d ' ')"
[[ "$member_count" == '4' ]] || fail "expected 4 ARM64 PRoot libraries, found $member_count"

TMPDIR_AUDIT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_AUDIT"' EXIT
tar -xJf "$archive" -C "$TMPDIR_AUDIT"
checksum_count=0
while read -r expected path; do
  [[ -z "${expected:-}" || "$expected" == \#* ]] && continue
  [[ "$path" == android/app/src/main/jniLibs/arm64-v8a/*.so ]] || fail "checksum path is not ARM64: $path"
  relative_path="${path#android/app/src/main/jniLibs/}"
  file="$TMPDIR_AUDIT/$relative_path"
  [[ -s "$file" ]] || fail "PRoot library missing from archive: $relative_path"
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || fail "PRoot checksum mismatch: $relative_path"
  checksum_count=$((checksum_count + 1))
done < "$checksums"
[[ "$checksum_count" == '4' ]] || fail "expected 4 ARM64 checksums, found $checksum_count"

workflow='.github/workflows/android-build.yml'
if grep -Fq 'id: localization_tests' "$workflow" \
  || grep -Fq 'test_android_localization.sh' "$workflow"; then
  fail 'Android Release workflow must not include the legacy standalone host localization test stage'
fi
if grep -Eq 'analyze_android_phase12\.sh|test_android_phase12\.sh|format_changed_dart\.sh|check_untranslated_pr\.sh' "$workflow"; then
  fail 'Android workflow still invokes non-essential broad Phase test/format/untranslated checks'
fi
if grep -Eq '\.github/scripts/(test|analyze)_android_phase[0-9]+\.sh' "$workflow"; then
  fail 'Android workflow must not invoke historical Phase regression suites'
fi
grep -Fq 'python3 .github/scripts/check_l10n_parity.py' "$workflow" || fail 'Android workflow does not validate ARB key/placeholder parity'
grep -Fq 'flutter gen-l10n' "$workflow" || fail 'Android workflow does not generate localized Dart sources'
# Historical Phase 13A–13D scripts remain available for traceability but must
# not be registered as gates in the current build workflow.
for test_file in \
  test/core/services/sandbox/environment_status_tool_test.dart \
  test/core/services/packages/package_manager_service_test.dart \
  test/core/services/extensions/conversational_extension_service_test.dart \
  test/features/home/services/built_in_tool_names_test.dart; do
done
grep -Fq "steps.flutter_pub_get.outcome == 'success'" <<< "$native_dependency_block" \
  || fail 'Linux GTK/GLib host dependencies must be prepared after Flutter dependencies resolve.'
if grep -Fq 'PHASE_TEST_SCOPE' <<< "$native_dependency_block"; then
  fail 'Linux GTK/GLib host dependencies must remain enabled in the isolated PHASE13O recovery scope.'
fi
if grep -Fq 'KELIVO_EXTENDED_PHASE13_TESTS' <<< "$native_dependency_block"; then
  fail 'Linux GTK/GLib host dependency setup must not be conditional on an obsolete Phase 13 mode.'
fi
grep -Fq 'Intentionally skipped by phase_test_scope=skill_doctor_recovery' .github/scripts/record_skipped_build_stages.sh \
  || fail 'Build report must distinguish intentional focused-recovery skips from failed prerequisites.'
grep -Fq 'id: full_flutter_analyze' "$workflow" \
  || fail 'Android workflow must include the complete Flutter analyzer gate'
grep -Fq 'bash .github/scripts/run_flutter_analyze_gate.sh' "$workflow" \
  || fail 'Complete Flutter analyzer must use the dedicated analysis quality gate'
grep -Fq 'flutter analyze --no-pub lib test integration_test' .github/scripts/run_flutter_analyze_gate.sh \
  || fail 'Complete Flutter analyzer gate must use the resolved dependency graph'
grep -Fq 'analyzer errors or warnings' .github/scripts/run_flutter_analyze_gate.sh \
  || fail 'Complete Flutter analyzer gate must block analyzer warnings and errors'
grep -Fq 'id: full_flutter_tests' "$workflow" \
  || fail 'Android workflow must include the complete Flutter unit/widget test gate'
grep -Fq 'flutter test --no-pub --reporter expanded' "$workflow" \
  || fail 'Complete Flutter tests must use the resolved dependency graph'
grep -Fq 'id: android_full_unit_tests' "$workflow" \
  || fail 'Android workflow must include the complete Android JVM/Robolectric test gate'
grep -Fq 'gradle --no-daemon -p android :app:testDebugUnitTest' "$workflow" \
  || fail 'Complete Android JVM/Robolectric test task is missing'
grep -Fq "github.ref == 'refs/heads/main'" "$workflow" \
  || fail 'Android emulator Skill E2E must run on main pushes'
  || fail 'Android workflow must include the Skill lifecycle emulator E2E gate'
for integration_test in \
  integration_test/browser_navigation_runtime_test.dart \
  integration_test/browser_workspace_runtime_test.dart \
  integration_test/browser_workspace_app_runtime_test.dart \
  integration_test/workspace/skill_execution_e2e_test.dart; do
    || fail "Android E2E runner is missing required integration test: $integration_test"
done

grep -Fq 'final packToUpdate = containingPack;' lib/core/services/extensions/conversational_extension_service.dart \
  || fail 'Skill-pack update must capture the nullable pack before the async callback'
grep -Fq "import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';" \
  lib/features/workspace/widgets/skills/skill_update_source.dart \
  || fail 'Skill update-source dialog must import the shared skill error formatter'

# The file-picker Linux platform package pulls DBus, which requires XML 7.x
# or PetitParser 7.x. Keep XML within the local compiler package's upper bound.
grep -Fq '  xml: 7.0.1' pubspec.yaml || fail 'XML must remain pinned to 7.0.1 for local vector_graphics_compiler compatibility'
grep -Fq '  petitparser: 7.0.2' pubspec.yaml || fail 'PetitParser must be pinned to 7.0.2 for file-picker/DBus compatibility'
grep -Fq 'xml: ">=6.3.0 <=7.0.1"' dependencies/vector_graphics_compiler/pubspec.yaml || fail 'Local vector_graphics_compiler XML compatibility bound changed; review dependency pins'
# PDF 31.x requires XML 6.x and cannot resolve with the XML 7 pin above.
# Keep all Syncfusion modules together on the first verified XML 7-compatible line.
for package in syncfusion_flutter_core syncfusion_flutter_sliders syncfusion_flutter_pdf; do
  grep -Fq "  ${package}: ^33.2.13+1" pubspec.yaml || fail "${package} must stay aligned on the XML 7-compatible 33.2.13+1 line"
done
# Keep packages that require Win32 6.x aligned with the matching native clipboard bridge.
grep -Fq '  file_picker: ^12.3.0' pubspec.yaml || fail 'file_picker must stay on the Win32 6.x-compatible v12 API line'
grep -Fq '  flutter_secure_storage: ^11.2.0' pubspec.yaml || fail 'secure storage must retain the current encrypted-storage implementation'
grep -Fq '  package_info_plus: ^10.2.2' pubspec.yaml || fail 'package_info_plus must stay on the Win32 6.x-compatible line'
grep -Fq '  share_plus: ^13.3.1' pubspec.yaml || fail 'share_plus must stay on the Win32 6.x-compatible line'
# Wakelock 1.8.1+ requires dbus ^0.8.0, conflicting with the Linux federation
# package pulled by flutter_local_notifications 17.2.x (dbus ^0.7.8).
# Version 1.8.0 keeps the earlier DBus constraint and already supports Win32 6.x.
grep -Fq '  flutter_local_notifications: ^17.2.3' pubspec.yaml || fail 'Review notification plugin DBus compatibility before changing its major line'
grep -Fq '  wakelock_plus: 1.8.0' pubspec.yaml || fail 'wakelock_plus must be pinned exactly to 1.8.0 to avoid the dbus 0.8.0 conflict'
grep -Fq '  super_clipboard: 0.10.0-dev.2' pubspec.yaml || fail 'super_clipboard must be pinned to the matching native extension compatibility release'
grep -Fq '  super_native_extensions: 0.10.0-dev.2' pubspec.yaml || fail 'super_native_extensions must allow the device_info_plus 13 / Win32 6 dependency line'
grep -Fq '  irondash_message_channel: ^0.8.0-dev.0' pubspec.yaml || fail 'irondash_message_channel must satisfy super_native_extensions 0.10.0-dev.2'
if ! grep -Fq 'minSdk = maxOf(flutter.minSdkVersion, 24)' android/app/build.gradle.kts; then
  fail 'Android minSdk must be at least 24 for flutter_secure_storage 11.x and super_clipboard native support'
fi
if ! grep -Fq 'android:name="com.superlist.super_native_extensions.DataProvider"' android/app/src/main/AndroidManifest.xml \
  || ! grep -Fq 'android:authorities="${applicationId}.SuperClipboardDataProvider"' android/app/src/main/AndroidManifest.xml \
  || ! grep -Fq 'android:grantUriPermissions="true"' android/app/src/main/AndroidManifest.xml; then
  fail 'Android manifest is missing the super_clipboard DataProvider required for image/custom clipboard writes'
fi
if grep -Eq '^  reorderable_grid_view:' pubspec.yaml; then
  fail 'Unused reorderable_grid_view dependency must not be reintroduced without a real source import'
fi

# dependency/native-hook setup and before localization and the Android build.
previous_line=0
for step_id in \
  setup_flutter \
  toolchain_versions \
  flutter_pub_get \
  linux_test_native_deps \
  l10n_parity \
  generate_l10n \
  full_flutter_analyze \
  full_flutter_tests \
  setup_java \
  setup_gradle \
  android_sdk_components \
  android_full_unit_tests \
  prepare_android_plugin_registrant \
  build_android_arm64 \
  package_apk \
  upload_apk; do
  current_line="$(grep -n -m1 -E "^[[:space:]]*id: ${step_id}$" "$workflow" | cut -d: -f1)"
  [[ -n "$current_line" ]] || fail "Android workflow is missing required step id: $step_id"
  (( current_line > previous_line )) || fail "Android workflow step is out of order: $step_id"
  previous_line="$current_line"
done

# Toolchain preparation is gated on its direct prerequisite. Focused Phase
# lanes are independent diagnostics: they continue after another lane fails,
# while the final Android build remains success-gated.
for step_id in toolchain_versions flutter_pub_get; do
  step_line="$(grep -n -m1 -E "^[[:space:]]*id: ${step_id}$" "$workflow" | cut -d: -f1)"
  block="$(sed -n "${step_line},$((step_line + 3))p" "$workflow")"
  grep -Fq 'if: success()' <<< "$block" || fail "Toolchain step lacks success() gate: $step_id"
done
for step_id in \
  step_line="$(grep -n -m1 -E "^[[:space:]]*id: ${step_id}$" "$workflow" | cut -d: -f1)"
  block="$(sed -n "${step_line},$((step_line + 3))p" "$workflow")"
  grep -Fq 'steps.flutter_pub_get.outcome' <<< "$block" \
    || fail "Focused Phase test must require resolved Flutter dependencies: $step_id"
  grep -Fq 'steps.linux_test_native_deps.outcome' <<< "$block" \
    || fail "Focused Phase test must require Linux native test dependencies: $step_id"
  grep -Fq 'env.PHASE_TEST_SCOPE' <<< "$block" \
    || fail "Focused Phase test is missing the documented recovery-scope control: $step_id"
done
  step_line="$(grep -n -m1 -E "^[[:space:]]*id: ${step_id}$" "$workflow" | cut -d: -f1)"
  block="$(sed -n "${step_line},$((step_line + 3))p" "$workflow")"
  grep -Fq 'steps.flutter_pub_get.outcome' <<< "$block" \
    || fail "Phase 13O/13P diagnostics must continue after earlier test failures: $step_id"
  grep -Fq 'steps.linux_test_native_deps.outcome' <<< "$block" \
    || fail "Phase 13O/13P diagnostics must require Linux native dependencies: $step_id"
done
for step_id in l10n_parity generate_l10n full_flutter_analyze full_flutter_tests setup_java setup_gradle \
  prepare_android_plugin_registrant build_android_arm64 package_apk upload_apk; do
  step_line="$(grep -n -m1 -E "^[[:space:]]*id: ${step_id}$" "$workflow" | cut -d: -f1)"
  block="$(sed -n "${step_line},$((step_line + 3))p" "$workflow")"
  grep -Fq 'if: success()' <<< "$block" || fail "Release prerequisite/build step must remain success-gated: $step_id"
done

native_line="$(grep -n -m1 -E '^[[:space:]]+id: linux_test_native_deps$' "$workflow" | cut -d: -f1)"

# The build-mode-specific plugin registrant must be regenerated and validated
# after SDK setup, immediately before the real no-pub ARM64 build.
registrant_line="$(grep -n -m1 -E '^[[:space:]]+id: prepare_android_plugin_registrant$' "$workflow" | cut -d: -f1)"
sdk_line="$(grep -n -m1 -E '^[[:space:]]+id: android_sdk_components$' "$workflow" | cut -d: -f1)"
build_line="$(grep -n -m1 -E '^[[:space:]]+id: build_android_arm64$' "$workflow" | cut -d: -f1)"
[[ -n "$registrant_line" && -n "$sdk_line" && -n "$build_line" ]] || fail 'Android release plugin registrant preparation step is missing'
(( sdk_line < registrant_line && registrant_line < build_line )) || fail 'Android plugin registrant preparation must run immediately before APK build'
grep -Fq 'flutter build apk --no-pub --"$BUILD_MODE" --target-platform android-arm64' "$workflow" \
  || fail 'Final Android ARM64 build must use --no-pub after mode-specific plugin registrant generation'

  || fail 'Android-only audit must run the Phase 13F CI self-test'
  || fail 'Android-only audit must run the Phase 13G CI self-test'
  || fail 'Android-only audit must run the Phase 13H CI self-test'
for phase in l m n o p; do
  grep -Fq "bash .github/scripts/test_phase13${phase}_ci.sh" .github/scripts/audit_android_only.sh \
    || fail "Android-only audit must run the Phase 13${phase^^} CI self-test"
done
bash .github/scripts/release_hardening_audit.sh
if grep -Eq 'dart analyze --fatal-infos lib test integration_test' "$workflow"; then
  fail 'Android workflow must use the pinned Flutter analyzer gate rather than an unpinned Dart analyzer command'
fi

