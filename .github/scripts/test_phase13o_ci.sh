#!/usr/bin/env bash
# Phase 13O CI wiring self-test. It does not need Flutter, Dart or Gradle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

bash -n .github/scripts/preflight_phase13o_tests.sh
bash -n .github/scripts/run_phase13o_tests.sh
bash .github/scripts/preflight_phase13o_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13o_syntax_preflight phase13o_ci_self_test phase13o_preflight phase13o_tests; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
for file in \
  lib/core/services/skills/skill_doctor_service.dart \
  lib/core/services/runtime_profiles/runtime_profile_service.dart \
  lib/features/workspace/pages/skill_doctor_page.dart \
  lib/features/workspace/pages/skills_page_mobile_layout.dart \
  lib/features/workspace/pages/skills_page_desktop_layout.dart \
  lib/features/workspace/pages/workspace_settings_page.dart \
  test/core/services/skills/skill_doctor_policy_test.dart \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart; do
  grep -Fq "$file" "$workflow" || { echo "Phase 13O syntax preflight is missing $file" >&2; exit 1; }
done
for file in skill_doctor_policy_test.dart skill_readiness_phase13l_test.dart skill_import_manifest_test.dart runtime_profile_service_test.dart; do
  grep -Fq "$file" .github/scripts/run_phase13o_tests.sh || { echo "Phase 13O runner is missing $file" >&2; exit 1; }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi
# Recovery mode must skip only the already-passed 13E–13N lanes. The 13O and
# 13P diagnostics must still run, and the later APK build remains success-gated.
python3 - <<'PY_RECOVERY_CHECK'
from pathlib import Path
import re
workflow = Path('.github/workflows/android-build.yml').read_text(encoding='utf-8')
lines = workflow.splitlines()
def condition_for(step_id):
    for index, line in enumerate(lines):
        if re.fullmatch(r'\s*id: ' + re.escape(step_id), line):
            for following in lines[index + 1:index + 4]:
                match = re.match(r'\s*if: (.+)$', following)
                if match:
                    return match.group(1)
            raise SystemExit(f'FAIL: step {step_id} has no explicit condition')
    raise SystemExit(f'FAIL: missing workflow step {step_id}')
if 'phase_test_scope:' not in workflow or 'skill_doctor_recovery' not in workflow:
    raise SystemExit('FAIL: workflow lacks the explicit Skill Doctor recovery scope')
for step_id in [
    'phase13e_preflight', 'phase13e_tests', 'phase13f_preflight', 'phase13f_tests',
    'phase13g_preflight', 'phase13g_tests', 'phase13h_ci_self_test', 'phase13h_preflight', 'phase13h_tests',
    'phase13i_preflight', 'phase13i_tests', 'phase13j_preflight', 'phase13j_tests',
    'phase13k_ci_self_test', 'phase13k_preflight', 'phase13k_tests',
    'phase13l_syntax_preflight', 'phase13l_ci_self_test', 'phase13l_preflight', 'phase13l_tests',
    'phase13m_syntax_preflight', 'phase13m_ci_self_test', 'phase13m_preflight', 'phase13m_tests',
    'phase13n_syntax_preflight', 'phase13n_ci_self_test', 'phase13n_preflight', 'phase13n_tests',
]:
    condition = condition_for(step_id)
    if "env.PHASE_TEST_SCOPE != 'skill_doctor_recovery'" not in condition:
        raise SystemExit(f'FAIL: {step_id} is not excluded by the isolated recovery scope')
    if 'steps.flutter_pub_get.outcome' not in condition or 'steps.linux_test_native_deps.outcome' not in condition:
        raise SystemExit(f'FAIL: {step_id} must continue independently after another phase test fails')
for step_id in [
    'phase13o_syntax_preflight', 'phase13o_ci_self_test', 'phase13o_preflight', 'phase13o_tests',
    'phase13p_syntax_preflight', 'phase13p_ci_self_test', 'phase13p_preflight', 'phase13p_tests',
]:
    condition = condition_for(step_id)
    if 'steps.flutter_pub_get.outcome' not in condition or 'steps.linux_test_native_deps.outcome' not in condition:
        raise SystemExit(f'FAIL: {step_id} must continue after earlier test failures when prerequisites are ready')
    if 'PHASE_TEST_SCOPE' in condition:
        raise SystemExit(f'FAIL: recovery mode must not skip {step_id}')
if 'PHASE_TEST_SCOPE' in condition_for('linux_test_native_deps'):
    raise SystemExit('FAIL: recovery mode skipped a native dependency required by Flutter tests')
if 'Intentionally skipped by phase_test_scope=skill_doctor_recovery' not in Path('.github/scripts/record_skipped_build_stages.sh').read_text(encoding='utf-8'):
    raise SystemExit('FAIL: build report does not distinguish intentional recovery-mode skips')
for step_id in ['prepare_android_plugin_registrant', 'build_android_arm64', 'package_apk', 'upload_apk']:
    if condition_for(step_id) != 'success()':
        raise SystemExit(f'FAIL: {step_id} must remain gated on all required tests succeeding')
print('PASS: recovery scope skips only PHASE13E–13N focused lanes')
print('PASS: PHASE13O and PHASE13P diagnostics continue after earlier test failures')
print('PASS: Flutter native test dependencies remain enabled in recovery mode')
print('PASS: Android APK creation remains gated on complete CI success')
PY_RECOVERY_CHECK

echo 'Phase 13O CI wiring self-test passed.'
