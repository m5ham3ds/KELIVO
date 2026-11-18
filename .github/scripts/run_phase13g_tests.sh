#!/usr/bin/env bash
# Focused Phase 13G regressions only. Historical Phase 13A–13D suites are not repeated.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_test() {
  echo
  echo "===== Phase 13G: flutter test $* ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded "$@"
}

run_test test/core/services/mobile_background_test.dart
run_test test/features/home/services/tool_approval_service_test.dart
run_test test/settings_provider_mobile_background_test.dart
run_test test/features/settings/pages/mobile_background_settings_page_test.dart

echo
 echo 'Phase 13G focused regression suite passed.'
