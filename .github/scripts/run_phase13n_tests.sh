#!/usr/bin/env bash
# Focused Phase 13N Skill permission and execution-boundary regressions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_execution_permissions_test.dart \
  test/core/services/skills/skill_execution_security_test.dart \
  test/core/services/extensions/extension_permission_policy_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/skills/skill_executor_test.dart

echo 'Phase 13N Skill permission, single-run grant and executor boundary tests passed.'
