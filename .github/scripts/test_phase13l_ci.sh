#!/usr/bin/env bash
# CI wiring self-test for Phase 13L; no Flutter/Dart SDK required.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13l_tests.sh \
  .github/scripts/run_phase13l_tests.sh \
  test/core/services/skills/skill_requirements_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart \
  test/core/services/skills/skill_readiness_phase13l_test.dart; do
  [[ -s "$file" ]] || { echo "Missing Phase 13L CI input: $file" >&2; exit 1; }
done

bash -n .github/scripts/preflight_phase13l_tests.sh
bash -n .github/scripts/run_phase13l_tests.sh
bash .github/scripts/preflight_phase13l_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13l_syntax_preflight phase13l_ci_self_test phase13l_preflight phase13l_tests; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
for dart_file in \
  lib/core/services/skills/skill_requirements.dart \
  lib/core/services/skills/skill_readiness.dart \
  lib/core/services/skills/skill_import_manifest.dart \
  lib/features/workspace/widgets/skills/skill_detail.dart \
  test/core/services/skills/skill_requirements_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart \
  test/core/services/skills/skill_readiness_phase13l_test.dart; do
  grep -Fq "$dart_file" "$workflow" || { echo "Phase 13L Dart syntax preflight is missing $dart_file" >&2; exit 1; }
done
for test_file in skill_requirements_test.dart skill_import_manifest_test.dart skill_readiness_phase13l_test.dart; do
  grep -Fq "$test_file" .github/scripts/run_phase13l_tests.sh || { echo "Phase 13L runner is missing $test_file" >&2; exit 1; }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13L CI wiring self-test passed.'
