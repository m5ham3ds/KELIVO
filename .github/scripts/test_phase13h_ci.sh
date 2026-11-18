#!/usr/bin/env bash
# CI wiring self-test for Phase 13H; does not require Flutter/Dart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for file in \
  .github/scripts/preflight_phase13h_tests.sh \
  .github/scripts/run_phase13h_tests.sh \
  test/core/services/chat/document_text_extractor_test.dart \
  test/features/home/services/message_builder_sandbox_files_test.dart \
  test/core/services/workspace/workspace_session_sync_test.dart \
  test/core/services/workspace/workspace_tools_service_test.dart; do
  [[ -s "$file" ]] || { echo "Missing Phase 13H CI input: $file" >&2; exit 1; }
done

bash -n .github/scripts/preflight_phase13h_tests.sh
bash -n .github/scripts/run_phase13h_tests.sh
bash .github/scripts/preflight_phase13h_tests.sh

workflow=.github/workflows/android-build.yml
for id in phase13h_preflight phase13h_tests; do
  grep -Fq "id: $id" "$workflow" || {
    echo "Workflow is missing $id" >&2
    exit 1
  }
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  echo 'Historical Phase 13A–13D suites were re-enabled.' >&2
  exit 1
fi

echo 'Phase 13H CI wiring self-test passed.'
