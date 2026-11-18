#!/usr/bin/env bash
# Focused Phase 13I background execution reliability regressions.
# Historical Phase 13A–13D suites remain excluded.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_test() {
  echo
  echo "===== Phase 13I: flutter test $* ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded "$@"
}

run_test test/settings_provider_mobile_background_test.dart
run_test test/core/services/mobile_background_test.dart

echo 'Phase 13I focused background execution regressions passed.'
