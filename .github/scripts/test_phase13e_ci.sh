#!/usr/bin/env bash
# Static regression test for the lean Phase 13E-only CI orchestration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "FAIL: $*" >&2; exit 1; }
workflow='.github/workflows/android-build.yml'
runner='.github/scripts/run_phase13e_tests.sh'
preflight='.github/scripts/preflight_phase13e_tests.sh'
for file in "$workflow" "$runner" "$preflight"; do
  [[ -s "$file" ]] || fail "Missing Phase 13E CI component: $file"
done
for retired_id in phase13_test_preflight phase13a_import_tests phase13b_executor_tests phase13c_workspace_environment_tests phase13d_execution_security_tests; do
  if grep -Fq "id: $retired_id" "$workflow"; then fail "Historical workflow stage has returned: $retired_id"; fi
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  fail 'Active workflow references a retired Phase 13A–13D test runner.'
fi
if grep -Fq 'run_extended_phase13_tests' "$workflow" || grep -Fq 'KELIVO_EXTENDED_PHASE13_TESTS' "$workflow"; then
  fail 'Obsolete Phase 13A–13D extended-test switch remains in the workflow.'
fi
grep -Fq 'id: phase13e_preflight' "$workflow" || fail 'Phase 13E preflight step is not registered.'
grep -Fq 'id: phase13e_tests' "$workflow" || fail 'Phase 13E regression step is not registered.'
grep -Fq 'preflight_phase13e_tests.sh' "$workflow" || fail 'Workflow does not invoke Phase 13E preflight.'
grep -Fq 'run_phase13e_tests.sh' "$workflow" || fail 'Workflow does not invoke Phase 13E regression runner.'
grep -Fq 'test_phase13e_ci.sh' .github/scripts/audit_android_only.sh || fail 'Android-only audit does not run the Phase 13E CI self-test.'
for target in \
  test/core/services/sandbox/environment_status_tool_test.dart \
  test/features/home/services/tool_handler_workspace_gating_test.dart \
  test/core/services/packages/package_manager_service_test.dart \
  test/core/services/extensions/conversational_extension_service_test.dart \
  test/features/home/services/built_in_tool_names_test.dart \
  test/core/services/skills/skill_bundle_import_phase13e_test.dart \
  test/core/services/skills/skill_missing_companion_refs_phase13e_test.dart \
  test/core/services/skills/github_skill_ref_phase13e_test.dart \
  test/core/services/skills/skill_pack_independent_members_phase13e_test.dart \
  test/features/workspace/skills/skill_pack_original_visibility_phase13e_test.dart \
  test/features/home/services/file_upload_any_attachment_phase13e_test.dart; do
  grep -Fq "$target" "$runner" || fail "Phase 13E runner is missing target $target"
done
for test_title in \
  'exposes a read-only environment diagnostic tool with bounded detail' \
  'reports the KELIVO package ledger even without a registered runtime' \
  'does not recommend apt installation when RootFS exists but PRoot host runtime is not registered' \
  'exposes shell for a ready conversation sandbox with a manual approval boundary' \
  'keeps chat-scoped file tools unbound from synthetic project ids' \
  'routes chat-scoped shell calls to PRoot after fresh approval in Full Access' \
  'does not report a non-PRoot runtime as Ubuntu reachable' \
  'returns a concise structured Ubuntu/PRoot result to the model' \
  'ready conversation PRoot context exposes Shell and Skill execution' \
  'provides a bounded package-ledger snapshot without live verification' \
  'read-only update check detects a new GitHub revision without mutating the installed Skill' \
  'extension list preserves original Skill status and reports pack membership separately' \
  'Phase 13E registers environment inventory and read-only Skill update tools' \
  'expands nested Skill ZIPs while retaining their complete resources and package docs' \
  'SkillsService imports every compatible nested Skill atomically and preserves companion files' \
  'imports the exact direct GitHub ZIP file as a complete Skill archive' \
  'imports a direct GitHub ZIP containing a nested multi-Skill package' \
  'warns when a Skill references companion files missing from the source' \
  'does not warn for project state and generated asset paths' \
  'does not warn for relative companion files that are present' \
  'parses direct GitHub blob links to .skill files without converting them into folder URLs' \
  'rejects literal and encoded traversal in direct file references' \
  'accepts ordinary dotted and percent-encoded filenames' \
  'pack creation and activation never overwrite standalone Skill state' \
  'manual Skill Packs never take ownership of member updates' \
  'editing Pack membership never moves or deletes original Skills' \
  'one original Skill can belong to multiple independent packs' \
  'Skills page shows pack members as original standalone rows' \
  'conversation selector lists a pack member independently' \
  'device picker accepts any extension without loading all bytes into RAM'; do
  grep -Fq "$test_title" .github/scripts/run_phase13e_tests.sh .github/scripts/preflight_phase13e_tests.sh \
    || fail "A Phase 13E regression case is not wired into the focused runner/preflight: $test_title"
done
if grep -Fq 'conversation_tool_permissions_test.dart' "$runner"; then
  fail 'A historical conversation-permission test file must not be rerun in the Phase 13E lane.'
fi
bash -n .github/scripts/preflight_phase13e_tests.sh
bash -n .github/scripts/run_phase13e_tests.sh
printf 'Phase 13E CI self-test passed: only Phase 13E-specific cases run; historical Phase 13A–13D tests are excluded.\n'
