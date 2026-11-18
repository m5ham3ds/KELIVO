#!/usr/bin/env bash
# CI wiring self-test for Phase 13N; does not require Flutter/Dart/Gradle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

bash -n .github/scripts/preflight_phase13n_tests.sh
bash -n .github/scripts/run_phase13n_tests.sh
bash .github/scripts/preflight_phase13n_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13n_syntax_preflight phase13n_ci_self_test phase13n_preflight phase13n_tests phase13n_android_guard_tests; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
for file in \
  lib/core/services/skills/skill_execution_permissions.dart \
  lib/core/services/skills/skill_execution_security.dart \
  lib/core/services/skills/skill_executor.dart \
  lib/features/home/services/tool_handler_service.dart \
  test/core/services/skills/skill_execution_permissions_test.dart \
  test/core/services/skills/skill_execution_security_test.dart \
  test/core/services/skills/skill_executor_test.dart; do
  grep -Fq "$file" "$workflow" || { echo "Phase 13N syntax check is missing $file" >&2; exit 1; }
done
for file in skill_execution_permissions_test.dart skill_execution_security_test.dart extension_permission_policy_test.dart skill_executor_test.dart; do
  grep -Fq "$file" .github/scripts/run_phase13n_tests.sh || { echo "Phase 13N runner is missing $file" >&2; exit 1; }
done
grep -Fq 'MountWriteGuardsTest' "$workflow" || { echo 'Android read-only guard tests are missing from CI' >&2; exit 1; }
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13N CI wiring self-test passed.'
