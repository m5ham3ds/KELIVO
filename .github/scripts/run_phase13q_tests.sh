#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
test_file="test/core/services/skills/skill_mcp_config_test.dart"
[[ -s "$test_file" ]] || { echo "Phase 13Q MCP config test missing: $test_file" >&2; exit 2; }
flutter test --no-pub --reporter expanded "$test_file"
