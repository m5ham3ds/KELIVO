#!/usr/bin/env bash
# Focused Phase 13P regressions. The real Android E2E lane is separate and
# opt-in because it provisions the PRoot environment on an emulator/device.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_execution_permissions_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart \
  test/core/services/skills/skills_service_test.dart \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart \
  test/core/services/mobile_background_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_executor_test.dart

echo 'Phase 13P focused Skill import, Profile, executor, artifact and background regressions passed.'
