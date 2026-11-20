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
record_skipped "phase13e_preflight" "Preflight focused Phase 13E regressions" "${PHASE13E_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13n_syntax_preflight" "Syntax-check Phase 13N Skill permission and execution changes" "${PHASE13N_SYNTAX_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13n_ci_self_test" "Validate Phase 13N focused CI wiring" "${PHASE13N_CI_SELF_TEST_OUTCOME:-unknown}"
record_skipped "phase13n_preflight" "Preflight Phase 13N Skill permissions and execution boundary" "${PHASE13N_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13n_tests" "Phase 13N per-run grants and Skill executor tests" "${PHASE13N_TESTS_OUTCOME:-unknown}"

record_skipped "phase13o_syntax_preflight" "Syntax-check Phase 13O Skill Doctor and Runtime Profile diagnostics" "${PHASE13O_SYNTAX_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13o_ci_self_test" "Validate Phase 13O focused CI wiring" "${PHASE13O_CI_SELF_TEST_OUTCOME:-unknown}"
record_skipped "phase13o_preflight" "Preflight Phase 13O Skill Doctor and evidence integrity" "${PHASE13O_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13o_tests" "Phase 13O Skill Doctor and Runtime Profile diagnostic tests" "${PHASE13O_TESTS_OUTCOME:-unknown}"
record_skipped "phase13p_syntax_preflight" "Syntax-check Phase 13P Android Skill lifecycle integration test" "${PHASE13P_SYNTAX_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13p_ci_self_test" "Validate Phase 13P focused CI and Android E2E wiring" "${PHASE13P_CI_SELF_TEST_OUTCOME:-unknown}"
record_skipped "phase13p_preflight" "Preflight Phase 13P Skill lifecycle coverage" "${PHASE13P_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13p_tests" "Phase 13P Skill lifecycle unit regressions" "${PHASE13P_TESTS_OUTCOME:-unknown}"
record_skipped "phase13p_android_e2e" "Browser and Skill lifecycle Android emulator E2E" "${PHASE13P_ANDROID_E2E_OUTCOME:-unknown}" "Not run because an earlier required stage did not succeed or the main-push/manual emulator gate was not selected."
record_skipped "phase13e_tests" "Phase 13E environment, update, approval and package-ledger tests" "${PHASE13E_TESTS_OUTCOME:-unknown}"
record_skipped "phase13f_preflight" "Preflight Phase 13F Skill composition and attachment library" "${PHASE13F_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13f_tests" "Phase 13F Skill composition, multi-file picker and shared upload reuse tests" "${PHASE13F_TESTS_OUTCOME:-unknown}"
record_skipped "phase13g_preflight" "Preflight Phase 13G background execution, approvals and progress notifications" "${PHASE13G_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13g_tests" "Phase 13G background task, approval action, notification progress and settings tests" "${PHASE13G_TESTS_OUTCOME:-unknown}"
record_skipped "phase13h_ci_self_test" "Validate Phase 13H ZIP attachment CI wiring" "${PHASE13H_CI_SELF_TEST_OUTCOME:-unknown}"
record_skipped "phase13h_preflight" "Preflight Phase 13H ZIP archive-aware attachment handling" "${PHASE13H_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13h_tests" "Phase 13H ZIP classification, chat sync, manifest routing and Skill import tests" "${PHASE13H_TESTS_OUTCOME:-unknown}"
record_skipped "phase13i_ci_self_test" "Validate Phase 13I background runtime recovery CI wiring" "${PHASE13I_CI_SELF_TEST_OUTCOME:-unknown}"
record_skipped "phase13i_preflight" "Preflight Phase 13I sticky foreground service and settings migration" "${PHASE13I_PREFLIGHT_OUTCOME:-unknown}"
record_skipped "phase13i_tests" "Phase 13I background execution settings and task lifecycle tests" "${PHASE13I_TESTS_OUTCOME:-unknown}"
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
