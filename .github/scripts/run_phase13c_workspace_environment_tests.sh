#!/usr/bin/env bash
# Phase 13C CI gate covers media-tool discovery and workspace profile scoping.
# The complete package/environment/video suite is opt-in for manual CI runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .github/scripts/phase13_test_gate.sh
phase13_require_ready "13C"

if [[ "${KELIVO_EXTENDED_PHASE13_TESTS:-false}" == "true" ]]; then
  echo "Extended Phase 13C regression mode: running all workspace/environment suites."
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    test/core/services/sandbox/environment_dependencies_test.dart \
    test/core/services/packages/package_manager_service_test.dart \
    test/core/services/video_engines/video_engine_service_safety_test.dart
else
  echo "Fast CI mode: running media preset and workspace Runtime Profile smoke tests."
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    --name 'media preset installs FFmpeg and verifies both ffmpeg and ffprobe|project Python operations inherit the workspace default Runtime Profile' \
    test/core/services/sandbox/environment_dependencies_test.dart \
    test/core/services/packages/package_manager_service_test.dart
fi

phase13_mark_passed "13C"
