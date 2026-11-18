#!/usr/bin/env bash
# Focused Phase 13O diagnostics, integrity, readiness and Profile-probe regressions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Run both independent test groups even when the policy/import group fails so
# one CI attempt reports every Phase 13O failure instead of hiding later tests.
status=0

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_doctor_policy_test.dart \
  test/core/services/skills/skill_readiness_phase13l_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart || status=$?

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart || status=$?

if [[ "$status" -ne 0 ]]; then
  echo "Phase 13O focused tests failed (exit $status)." >&2
  exit "$status"
fi

echo 'Phase 13O Skill Doctor and Runtime Profile diagnostic tests passed.'
