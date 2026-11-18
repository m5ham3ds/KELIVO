#!/usr/bin/env bash
# Minimal CI gate for approval and output-redaction boundaries. Detailed security
# and UI regressions remain available in extended/manual mode.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .github/scripts/phase13_test_gate.sh
phase13_require_ready "13D"

if [[ "${KELIVO_EXTENDED_PHASE13_TESTS:-false}" == "true" ]]; then
  echo "Extended Phase 13D regression mode: running security, permission and approval UI suites."
  flutter test --no-pub --concurrency=2 --reporter=expanded --tags=phase13d \
    test/core/services/skills/skill_executor_test.dart
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    test/core/services/skills/skill_execution_security_test.dart \
    test/core/services/conversation_tool_permissions_test.dart
  flutter test --no-pub --concurrency=1 --reporter=expanded \
    --plain-name "Skill execution approval displays the shared PRoot RootFS risk" \
    test/features/chat/widgets/workspace_tool_ui_test.dart
else
  echo "Fast CI mode: running explicit approval, RootFS risk and secret-redaction smoke tests."
  flutter test --no-pub --concurrency=2 --reporter=expanded --tags=phase13d \
    test/core/services/skills/skill_executor_test.dart
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    --name 'redacts environment-style credential names with prefixes and suffixes|approval and execution reports disclose the shared writable RootFS|missing, malformed and legacy grants never imply full access' \
    test/core/services/skills/skill_execution_security_test.dart \
    test/core/services/conversation_tool_permissions_test.dart
fi

phase13_mark_passed "13D"
