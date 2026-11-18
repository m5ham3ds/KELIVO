#!/usr/bin/env bash
# CI wiring self-test for Phase 13M; does not require Flutter/Dart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

bash -n .github/scripts/preflight_phase13m_tests.sh
bash -n .github/scripts/run_phase13m_tests.sh
bash .github/scripts/preflight_phase13m_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13m_syntax_preflight phase13m_ci_self_test phase13m_preflight phase13m_tests; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
for file in \
  lib/core/services/runtime_profiles/runtime_profile_models.dart \
  lib/core/services/runtime_profiles/runtime_profile_service.dart \
  lib/core/services/runtime_profiles/runtime_profile_tools.dart \
  lib/core/services/packages/package_manager_adapters.dart \
  lib/core/services/packages/package_manager_service.dart \
  lib/core/services/packages/dependency_resolver.dart \
  lib/features/home/services/tool_handler_service.dart \
  test/core/services/runtime_profiles/runtime_profile_models_test.dart \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart \
  test/core/services/runtime_profiles/runtime_profile_tools_test.dart \
  test/core/services/packages/dependency_resolver_test.dart \
  test/core/services/packages/package_manager_adapters_test.dart; do
  grep -Fq "$file" "$workflow" || { echo "Phase 13M syntax preflight is missing $file" >&2; exit 1; }
done
for test_file in dependency_resolver_test.dart package_manager_adapters_test.dart runtime_profile_models_test.dart runtime_profile_tools_test.dart runtime_profile_service_test.dart package_manager_service_test.dart; do
  grep -Fq "$test_file" .github/scripts/run_phase13m_tests.sh || { echo "Phase 13M runner is missing $test_file" >&2; exit 1; }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13M CI wiring self-test passed.'
