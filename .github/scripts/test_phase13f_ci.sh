#!/usr/bin/env bash
# Static regression test for the focused Phase 13F CI lane.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "FAIL: $*" >&2; exit 1; }
workflow='.github/workflows/android-build.yml'
runner='.github/scripts/run_phase13f_tests.sh'
preflight='.github/scripts/preflight_phase13f_tests.sh'
for file in "$workflow" "$runner" "$preflight"; do
  [[ -s "$file" ]] || fail "Missing Phase 13F CI component: $file"
done
for id in phase13f_preflight phase13f_tests; do
  grep -Fq "id: $id" "$workflow" || fail "Workflow is missing $id"
done
grep -Fq 'preflight_phase13f_tests.sh' "$workflow" || fail 'Workflow does not invoke Phase 13F preflight.'
grep -Fq 'run_phase13f_tests.sh' "$workflow" || fail 'Workflow does not invoke Phase 13F runner.'
grep -Fq 'test_phase13f_ci.sh' .github/scripts/audit_android_only.sh || fail 'Android-only audit does not run the Phase 13F CI self-test.'
for target in \
  test/core/services/skills/skill_composition_phase13f_test.dart \
  test/features/home/widgets/chat_attachment_library_sheet_phase13f_test.dart \
  test/core/services/chat/chat_attachment_library_phase13f_test.dart; do
  grep -Fq "$target" "$runner" || fail "Phase 13F runner is missing $target"
  grep -Fq "$target" "$preflight" || fail "Phase 13F preflight is missing $target"
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow" "$runner"; then
  fail 'A historical Phase 13A–13D test runner has been re-enabled.'
fi
if ! grep -Fq "'all_enabled'" lib/core/services/extensions/skill_composition_tools.dart; then
  fail 'The composition tool schema does not expose all_enabled.'
fi
if grep -Fq "'maxLength': 8000" lib/core/services/extensions/skill_composition_tools.dart; then
  fail 'The skill_compose JSON schema still prevents server-side task compaction.'
fi
bash -n "$runner"
bash -n "$preflight"
printf 'Phase 13F CI self-test passed: new focused cases are registered; Phase 13A–13D remain excluded.\n'
