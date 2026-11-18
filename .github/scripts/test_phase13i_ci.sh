#!/usr/bin/env bash
# CI wiring self-test for Phase 13I; does not require Flutter/Dart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13i_tests.sh \
  .github/scripts/run_phase13i_tests.sh \
  android/app/src/test/kotlin/com/psyche/kelivo/background/BackgroundRuntimeTest.kt \
  test/settings_provider_mobile_background_test.dart; do
  [[ -s "$file" ]] || { echo "Missing Phase 13I CI input: $file" >&2; exit 1; }
done

bash -n .github/scripts/preflight_phase13i_tests.sh
bash -n .github/scripts/run_phase13i_tests.sh
bash .github/scripts/preflight_phase13i_tests.sh
workflow=.github/workflows/android-build.yml
for id in phase13i_ci_self_test phase13i_preflight phase13i_tests android_background_unit_tests; do
  grep -Fq "id: $id" "$workflow" || {
    echo "Workflow is missing $id" >&2
    exit 1
  }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13I CI wiring self-test passed.'
