#!/usr/bin/env bash
# Lightweight CI contract test for Phase 13G wiring; no Flutter SDK is required.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13g_tests.sh \
  .github/scripts/run_phase13g_tests.sh \
  test/core/services/mobile_background_test.dart \
  test/features/home/services/tool_approval_service_test.dart \
  android/app/src/test/kotlin/com/psyche/kelivo/background/BackgroundRuntimeTest.kt; do
  test -s "$file" || { echo "Missing Phase 13G CI input: $file" >&2; exit 1; }
done

bash -n .github/scripts/preflight_phase13g_tests.sh
bash -n .github/scripts/run_phase13g_tests.sh
bash .github/scripts/preflight_phase13g_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13g_preflight phase13g_tests; do
  grep -Fq "id: $id" "$workflow" || { echo "Workflow is missing $id" >&2; exit 1; }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13G CI wiring self-test passed.'
