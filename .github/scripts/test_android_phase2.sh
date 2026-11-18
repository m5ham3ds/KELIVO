#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
MANIFEST="$ROOT/.github/ci/android-phase2-test-manifest.txt"
[[ -s "$MANIFEST" ]] || { echo "Missing Android Phase 2 test manifest: $MANIFEST" >&2; exit 1; }
mapfile -t TEST_FILES < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")
for file in "${TEST_FILES[@]}" test/features/chat/widgets/workspace_tool_ui_test.dart; do
  [[ -f "$file" ]] || { echo "Manifest test file is missing: $file" >&2; exit 1; }
done

echo "Running ${#TEST_FILES[@]} focused Android Phase 2 regression files."
flutter test --concurrency=4 --reporter=expanded "${TEST_FILES[@]}"

echo "Running only the two Android chat-tool UI regressions (tool catalog and live extension progress)."
flutter test --concurrency=1 --reporter=expanded \
  --name '^(each workspace tool renders its title and icon in the timeline|extension install tool shows live operation progress)$' \
  test/features/chat/widgets/workspace_tool_ui_test.dart
