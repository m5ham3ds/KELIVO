#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
MANIFEST="$ROOT/.github/ci/android-phase3-test-manifest.txt"
[[ -s "$MANIFEST" ]] || { echo "Missing Android Phase 3 test manifest: $MANIFEST" >&2; exit 1; }
mapfile -t TEST_FILES < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")
for file in "${TEST_FILES[@]}" test/features/chat/widgets/workspace_tool_ui_test.dart; do
  [[ -f "$file" ]] || { echo "Manifest test file is missing: $file" >&2; exit 1; }
done

echo "Analyzing production Dart sources and ${#TEST_FILES[@]} focused Phase 3 test files plus the selected Android chat UI test file."
dart analyze --fatal-infos lib "${TEST_FILES[@]}" test/features/chat/widgets/workspace_tool_ui_test.dart
