#!/usr/bin/env bash
# Focused Phase 13L runtime-evidence and Skill capability-readiness regressions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_requirements_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_import_manifest_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_readiness_phase13l_test.dart

echo 'Phase 13L focused Skill readiness and requirement-evidence tests passed.'
