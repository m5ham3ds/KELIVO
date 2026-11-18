#!/usr/bin/env bash
# CI wiring self-test for Phase 13K; does not require Flutter/Dart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13k_tests.sh \
  .github/scripts/run_phase13k_tests.sh \
  test/core/services/skills/skill_readiness_phase13k_test.dart \
  test/features/workspace/skills/skill_catalog_arabic_localization_phase13k_test.dart; do
  [[ -s "$file" ]] || { echo "Missing Phase 13K CI input: $file" >&2; exit 1; }
done

bash -n .github/scripts/preflight_phase13k_tests.sh
bash -n .github/scripts/run_phase13k_tests.sh
bash .github/scripts/preflight_phase13k_tests.sh
grep -Fq 'skill_catalog_arabic_localization_phase13k_test.dart' .github/scripts/run_phase13k_tests.sh || { echo 'Phase 13K runner is missing Arabic Skill catalog localization regression.' >&2; exit 1; }
for regression in \
  'CLI entrypoint paths match command evidence by executable basename' \
  'generic local script declarations remain conditional until runtime is identified' \
  'CLI runtime evidence is not trusted without profile identity and timestamp'; do
  grep -Fq "$regression" test/core/services/skills/skill_readiness_phase13k_test.dart || { echo "Phase 13K runtime regression is missing: $regression" >&2; exit 1; }
done
workflow=.github/workflows/android-build.yml
for id in phase13k_syntax_preflight phase13k_ci_self_test phase13k_preflight phase13k_tests; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
if ! grep -Fq 'dart format --output=none' "$workflow" || \
   ! grep -Fq 'lib/core/services/skills/skill_capability_registry.dart' "$workflow" || \
   ! grep -Fq 'lib/features/workspace/widgets/skills/skill_import.dart' "$workflow" || \
   ! grep -Fq 'test/core/services/skills/skill_readiness_phase13k_test.dart' "$workflow" || \
   ! grep -Fq 'test/features/workspace/skills/skill_catalog_arabic_localization_phase13k_test.dart' "$workflow"; then
  echo 'Phase 13K syntax preflight must parse the registry, Skill import UI and both focused test inputs before regression lanes.' >&2
  exit 1
fi
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi
if grep -Eq 'test/core/services/skills/(skill_composition_planner_test|skill_composition_phase13f_test)\.dart' .github/scripts/run_phase13k_tests.sh; then
  echo 'Phase 13K runner must remain focused and not rerun historical composition suites.' >&2
  exit 1
fi

echo 'Phase 13K CI wiring self-test passed.'
