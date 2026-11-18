#!/usr/bin/env bash
# CI wiring self-test for Phase 13J; does not require Flutter/Dart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13j_tests.sh \
  .github/scripts/run_phase13j_tests.sh \
  test/core/services/skills/skill_requirements_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart \
  test/core/services/skills/skills_service_test.dart \
  test/core/services/skills/skills_prompt_test.dart; do
  [[ -s "$file" ]] || { echo "Missing Phase 13J CI input: $file" >&2; exit 1; }
done

bash -n .github/scripts/preflight_phase13j_tests.sh
bash -n .github/scripts/run_phase13j_tests.sh
if ! grep -Fq -- '--plain-name' .github/scripts/run_phase13j_tests.sh; then
  echo 'Phase 13J runner must scope tests by name to avoid broad historical suite reruns.' >&2
  exit 1
fi
if grep -Eq 'test/core/services/skills/(skill_composition_planner_test|skill_composition_phase13f_test)\.dart' .github/scripts/run_phase13j_tests.sh; then
  echo 'Phase 13J runner must not re-run historical Skill composition suites.' >&2
  exit 1
fi
bash .github/scripts/preflight_phase13j_tests.sh
if ! grep -Fq 'does not claim no requirements when an external service is declared' test/core/services/skills/skill_requirements_test.dart; then
  echo 'Phase 13J analyzer suite is missing the external-service requirement regression.' >&2
  exit 1
fi
if ! grep -Fq 'Do not claim a Skill was installed until its files have been saved and verified.' lib/core/services/skills/skills_prompt.dart || \
   ! grep -Fq 'Do not claim a Skill was installed until its files have been saved and verified.' test/core/services/skills/skills_prompt_test.dart; then
  echo 'Phase 13J prompt policy and regression assertion are not aligned.' >&2
  exit 1
fi
if ! grep -Fq 'focused Phase 13E–13P regressions' .github/scripts/generate_build_report.py; then
  echo 'Build report metadata does not describe the active Phase 13E–13K regression lanes.' >&2
  exit 1
fi
workflow=.github/workflows/android-build.yml
for id in phase13j_ci_self_test phase13j_preflight phase13j_tests; do
  grep -Fq "id: $id" "$workflow" || {
    echo "Workflow is missing $id" >&2
    exit 1
  }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13J CI wiring self-test passed.'
