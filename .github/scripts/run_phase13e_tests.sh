#!/usr/bin/env bash
# Run only tests for current Phase 13E changes. Historical 13A–13D suites are
# retained for traceability but are intentionally not part of this build lane.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

run_test() {
  echo
  echo "===== Phase 13E: flutter test $* ====="
  flutter test --no-pub --concurrency=2 --reporter=expanded "$@"
}

# The previously failing diagnostic file must compile and run.
run_test test/core/services/sandbox/environment_status_tool_test.dart

# Verify the chat-scoped PRoot tool catalog exposes Shell/Skill execution only for a ready sandbox.
run_test --name 'ready conversation PRoot context exposes Shell and Skill execution' \
  test/features/home/services/tool_handler_workspace_gating_test.dart

# Validate only the new, isolated Phase 13E package-ledger snapshot test.
run_test --name 'provides a bounded package-ledger snapshot without live verification' \
  test/core/services/packages/package_manager_service_test.dart

# Validate only the new read-only upstream-update probe.
run_test --name 'read-only update check detects a new GitHub revision without mutating the installed Skill' \
  test/core/services/extensions/conversational_extension_service_test.dart
run_test --name 'extension list preserves original Skill status and reports pack membership separately' \
  test/core/services/extensions/conversational_extension_service_test.dart

# Validate only the new Phase 13E tool registration and approval policy catalog.
run_test --name 'Phase 13E registers environment inventory and read-only Skill update tools' \
  test/features/home/services/built_in_tool_names_test.dart

# Phase 13E skill-package and arbitrary chat-attachment regressions. These are
# new focused test files; no historical Phase 13A import suite is re-enabled.
run_test test/core/services/skills/skill_bundle_import_phase13e_test.dart
run_test test/core/services/skills/skill_missing_companion_refs_phase13e_test.dart
run_test test/core/services/skills/github_skill_ref_phase13e_test.dart
run_test --name 'pack creation and activation never overwrite standalone Skill state' test/core/services/skills/skill_pack_independent_members_phase13e_test.dart
run_test --name 'manual Skill Packs never take ownership of member updates' test/core/services/skills/skill_pack_independent_members_phase13e_test.dart
run_test --name 'editing Pack membership never moves or deletes original Skills' test/core/services/skills/skill_pack_independent_members_phase13e_test.dart
run_test --name 'one original Skill can belong to multiple independent packs' test/core/services/skills/skill_pack_independent_members_phase13e_test.dart
run_test test/features/workspace/skills/skill_pack_original_visibility_phase13e_test.dart
run_test --name 'device picker accepts any extension without loading all bytes into RAM' test/features/home/services/file_upload_any_attachment_phase13e_test.dart

echo
echo 'Phase 13E focused regression suite passed.'
