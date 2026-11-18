#!/usr/bin/env bash
# Focused Phase 13H ZIP attachment and archive-aware workspace regressions.
# Historical Phase 13A–13D suites are intentionally not repeated.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_test() {
  echo
  echo "===== Phase 13H: flutter test $* ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded "$@"
}

run_test test/core/services/chat/document_text_extractor_test.dart --plain-name ZIP
run_test test/features/home/services/file_upload_service_test.dart --plain-name "chat picker accepts every file type"
run_test test/features/home/services/message_builder_sandbox_files_test.dart --plain-name "Skill ZIP is routed to workspace tools rather than prompt text"
run_test test/core/services/workspace/workspace_session_sync_test.dart --plain-name "ZIP attachment sync exposes a real /chat file path"
run_test test/core/services/workspace/workspace_paths_test.dart --plain-name "nested session host paths keep the dedicated /chat mount"
run_test test/core/services/workspace/host_file_tools_test.dart --plain-name ZIP
run_test test/core/services/workspace/workspace_tools_service_test.dart --plain-name "ZIP"
run_test test/core/services/extensions/conversational_extension_service_test.dart --plain-name "installs an attached Skill ZIP from the conversation chat mount"
run_test test/core/services/extensions/conversational_extension_service_test.dart --plain-name "rejects an attached Skill ZIP with mismatched folder metadata with actionable details"

echo 'Phase 13H focused ZIP attachment regressions passed.'
