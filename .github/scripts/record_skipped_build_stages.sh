#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

record_skipped() {
  local step_id="$1"
  local title="$2"
  local outcome="${3:-unknown}"
  local note="${4:-Not run because an earlier required stage did not succeed.}"

  # Make the intentional recovery-mode skips distinguishable from failures or
  # missing prerequisites in the generated Markdown report.
  if [[ "${PHASE_TEST_SCOPE:-full}" == "skill_doctor_recovery" && "$step_id" =~ ^phase13[efghijklmn]_ ]]; then
    note="Intentionally skipped by phase_test_scope=skill_doctor_recovery; PHASE13E–13N passed on the parent commit and this run isolates the PHASE13O repair."
  fi

  if [[ "$outcome" == "skipped" ]]; then
    bash .github/scripts/record_ci_action.sh \
      "$step_id" "$title" "skipped" "$note"
  fi
}

record_skipped "toolchain_versions" "Flutter, Dart and Android SDK versions" "${TOOLCHAIN_VERSIONS_OUTCOME:-unknown}"
record_skipped "flutter_pub_get" "Resolve Flutter application dependencies" "${PUB_GET_OUTCOME:-unknown}"
record_skipped "linux_test_native_deps" "Prepare Linux GTK/GLib headers required by Flutter test hooks" "${LINUX_TEST_NATIVE_DEPS_OUTCOME:-unknown}" \
  "Not run because Flutter dependency resolution or an earlier required CI step did not succeed."

record_skipped "l10n_parity" "Validate Arabic localization keys and placeholders" "${L10N_PARITY_OUTCOME:-unknown}"
record_skipped "generate_l10n" "Generate Flutter localizations" "${GENERATE_L10N_OUTCOME:-unknown}"
record_skipped "full_flutter_analyze" "Analyze complete Flutter source" "${FULL_FLUTTER_ANALYZE_OUTCOME:-unknown}"
record_skipped "full_flutter_tests" "Run complete Flutter unit and widget test suite" "${FULL_FLUTTER_TESTS_OUTCOME:-unknown}"
record_skipped "setup_gradle" "Set up Gradle for focused Android runtime tests" "${SETUP_GRADLE_OUTCOME:-unknown}"
record_skipped "android_sdk_components" "Install Android NDK and CMake" "${ANDROID_SDK_COMPONENTS_OUTCOME:-unknown}"
record_skipped "android_full_unit_tests" "Complete Android JVM and Robolectric unit test suite" "${ANDROID_FULL_UNIT_TESTS_OUTCOME:-unknown}"
record_skipped "prepare_android_plugin_registrant" "Prepare build-mode Android plugin registrant" "${RELEASE_PLUGIN_REGISTRANT_OUTCOME:-unknown}"
record_skipped "build_android_arm64" "Build Android ARM64 APK" "${BUILD_ANDROID_OUTCOME:-unknown}"
record_skipped "package_apk" "Package APK and calculate SHA-256" "${PACKAGE_APK_OUTCOME:-unknown}"
