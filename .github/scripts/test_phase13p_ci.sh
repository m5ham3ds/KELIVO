#!/usr/bin/env bash
# Phase 13P CI wiring self-test. Does not need Flutter, Dart, Gradle or Android.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13p_tests.sh \
  .github/scripts/run_phase13p_tests.sh \
  .github/scripts/run_phase13p_android_e2e.sh; do
  bash -n "$file"
done
bash .github/scripts/preflight_phase13p_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13p_syntax_preflight phase13p_ci_self_test phase13p_preflight phase13p_tests phase13p_android_e2e; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
for file in skill_execution_e2e_test.dart skill_executor_test.dart skill_execution_permissions_test.dart skills_service_test.dart runtime_profile_service_test.dart mobile_background_test.dart; do
  grep -Fq "$file" .github/scripts/run_phase13p_tests.sh .github/scripts/preflight_phase13p_tests.sh || {
    echo "Phase 13P test wiring is missing $file" >&2; exit 1;
  }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13P CI wiring self-test passed.'
