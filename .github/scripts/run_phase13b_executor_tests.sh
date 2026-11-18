#!/usr/bin/env bash
# Phase 13B default CI gate runs only the primary execution path and one
# deterministic profile/interpreter rejection. Full regression remains optional.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .github/scripts/phase13_test_gate.sh
phase13_require_ready "13B"

if [[ "${KELIVO_EXTENDED_PHASE13_TESTS:-false}" == "true" ]]; then
  echo "Extended Phase 13B regression mode: running executor, runtime-profile and tool-catalog suites."
  flutter test --no-pub --concurrency=2 --reporter=expanded --exclude-tags=phase13d \
    test/core/services/skills/skill_executor_test.dart \
    test/core/services/runtime_profiles/runtime_profile_models_test.dart \
    test/core/services/runtime_profiles/runtime_profile_service_test.dart \
    test/core/services/tools/built_in_tool_catalog_test.dart
else
  echo "Fast CI mode: running declared-script execution and interpreter/profile rejection smoke tests."
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    --name 'executes only a declared script from a verified snapshot and records output|rejects execution when the selected interpreter is not in the profile' \
    test/core/services/skills/skill_executor_test.dart
fi

phase13_mark_passed "13B"
