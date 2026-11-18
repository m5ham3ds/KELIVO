#!/usr/bin/env bash
# Focused Phase 13F tests only. Historical 13A–13D suites are not repeated.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_test() {
  echo
  echo "===== Phase 13F: flutter test $* ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded "$@"
}

run_test test/core/services/skills/skill_composition_phase13f_test.dart
run_test test/features/home/widgets/chat_attachment_library_sheet_phase13f_test.dart
run_test test/core/services/chat/chat_attachment_library_phase13f_test.dart

echo
 echo 'Phase 13F focused regression suite passed.'
