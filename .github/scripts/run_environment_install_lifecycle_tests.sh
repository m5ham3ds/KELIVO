#!/usr/bin/env bash
# Focused regressions for Environment image, Presets, Media tools and task state.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_test() {
  echo
  echo "===== Environment install lifecycle: flutter test $* ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded "$@"
}

run_test test/core/services/sandbox/environment_dependencies_test.dart
run_test test/features/workspace/environment/environment_presets_test.dart
run_test test/core/services/sandbox/environment_installer_test.dart
run_test test/core/services/mobile_background_test.dart

echo "Environment image/package installation lifecycle regressions passed."
