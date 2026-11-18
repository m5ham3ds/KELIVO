#!/usr/bin/env bash
# Focused Phase 13J Skill requirement discovery regressions.
# Run only tests added/updated for this phase; do not re-run the historical
# Phase 13A–13D import/executor/workspace/execution suites or broad legacy suites.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_named_test() {
  local test_name="$1"
  local test_file="$2"
  echo
  echo "===== Phase 13J: $test_file :: $test_name ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    --plain-name "$test_name" "$test_file"
}

# The dedicated Phase 13J analyzer test file contains only new focused tests.
echo
echo '===== Phase 13J: complete dedicated requirement analyzer test file ====='
flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_requirements_test.dart

# Only the Phase 13J additions in the existing manifest/service/prompt files.
run_named_test \
  'persists a detailed environment requirements inventory with the import manifest' \
  test/core/services/skills/skill_import_manifest_test.dart
run_named_test \
  'requirement scan limits are reported without marking preserved Skill files incomplete' \
  test/core/services/skills/skill_import_manifest_test.dart
run_named_test \
  'rebuilds and persists requirement inventory for a legacy installed Skill' \
  test/core/services/skills/skills_service_test.dart
run_named_test \
  'core capabilities are independent from installed Skills' \
  test/core/services/skills/skills_prompt_test.dart

echo 'Phase 13J focused Skill requirement discovery regressions passed.'
