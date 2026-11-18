#!/usr/bin/env bash
# Focused Phase 13K capability registry and Skill readiness regressions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/features/workspace/skills/skill_catalog_arabic_localization_phase13k_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_readiness_phase13k_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  --plain-name 'persists a source-bound Skill readiness assessment in the import sidecar' \
  test/core/services/skills/skills_service_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  --plain-name 'core capabilities are independent from installed Skills' \
  test/core/services/skills/skills_prompt_test.dart

echo 'Phase 13K focused Skill readiness and capability registry tests passed.'
