#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
test_files=(
  "test/core/services/skills/skill_mcp_config_test.dart"
  "test/core/services/skills/skill_mcp_registry_test.dart"
  "test/core/providers/mcp_provider_stdio_test.dart"
  "test/core/providers/skill_mcp_real_process_test.dart"
)
for test_file in "${test_files[@]}"; do
  [[ -s "$test_file" ]] || { echo "Skill MCP lifecycle test missing: $test_file" >&2; exit 2; }
done
flutter test --no-pub --reporter expanded "${test_files[@]}"
