#!/usr/bin/env bash
# Structural preflight for the active Phase 13E regression lane only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
REPORT_DIR="${KELIVO_CI_REPORT_DIR:-$ROOT/build-report}"
mkdir -p "$REPORT_DIR/logs"
LOG="$REPORT_DIR/phase13e-preflight.txt"
exec > >(tee "$LOG") 2>&1

fail() { echo "FAIL: $*" >&2; exit 1; }
record() { echo "$*"; }
record 'KELIVO Phase 13E focused preflight'
record "UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"

command -v flutter >/dev/null 2>&1 || fail 'Flutter is unavailable before Phase 13E tests.'
command -v dart >/dev/null 2>&1 || fail 'Dart is unavailable before Phase 13E tests.'
[[ -s .dart_tool/package_config.json ]] || fail 'Flutter package configuration is missing; resolve dependencies first.'
[[ -s .github/scripts/run_phase13e_tests.sh ]] || fail 'Phase 13E regression runner is missing.'
[[ -s .github/scripts/test_phase13e_ci.sh ]] || fail 'Phase 13E CI self-test is missing.'

# Do not re-run historically verified Phase 13A–13D gates in this pipeline.
workflow='.github/workflows/android-build.yml'
for retired_id in phase13_test_preflight phase13a_import_tests phase13b_executor_tests phase13c_workspace_environment_tests phase13d_execution_security_tests; do
  if grep -Fq "id: $retired_id" "$workflow"; then
    fail "Historical stage $retired_id is still wired into the active build workflow."
  fi
done
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' "$workflow"; then
  fail 'An already-verified Phase 13A–13D runner is still referenced by the active workflow.'
fi

require_case() {
  local file="$1" title="$2"
  [[ -s "$file" ]] || fail "Missing Phase 13E test file: $file"
  grep -Fq "$title" "$file" || fail "Missing Phase 13E regression case: $file :: $title"
  record "PASS: $file :: $title"
}
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'exposes a read-only environment diagnostic tool with bounded detail'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'reports the KELIVO package ledger even without a registered runtime'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'does not recommend apt installation when RootFS exists but PRoot host runtime is not registered'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'exposes shell for a ready conversation sandbox with a manual approval boundary'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'keeps chat-scoped file tools unbound from synthetic project ids'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'routes chat-scoped shell calls to PRoot after fresh approval in Full Access'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'does not report a non-PRoot runtime as Ubuntu reachable'
require_case 'test/core/services/sandbox/environment_status_tool_test.dart' 'returns a concise structured Ubuntu/PRoot result to the model'
require_case 'test/features/home/services/tool_handler_workspace_gating_test.dart' 'ready conversation PRoot context exposes Shell and Skill execution'
require_case 'test/core/services/skills/skill_bundle_import_phase13e_test.dart' 'expands nested Skill ZIPs while retaining their complete resources and package docs'
require_case 'test/core/services/skills/skill_bundle_import_phase13e_test.dart' 'SkillsService imports every compatible nested Skill atomically and preserves companion files'
require_case 'test/core/services/skills/skill_bundle_import_phase13e_test.dart' 'imports the exact direct GitHub ZIP file as a complete Skill archive'
require_case 'test/core/services/skills/skill_bundle_import_phase13e_test.dart' 'imports a direct GitHub ZIP containing a nested multi-Skill package'
require_case 'test/core/services/skills/skill_missing_companion_refs_phase13e_test.dart' 'warns when a Skill references companion files missing from the source'
require_case 'test/core/services/skills/skill_missing_companion_refs_phase13e_test.dart' 'does not warn for project state and generated asset paths'
require_case 'test/core/services/skills/skill_missing_companion_refs_phase13e_test.dart' 'does not warn for relative companion files that are present'
require_case 'test/core/services/skills/github_skill_ref_phase13e_test.dart' 'parses direct GitHub blob links to .skill files without converting them into folder URLs'
require_case 'test/core/services/skills/github_skill_ref_phase13e_test.dart' 'rejects literal and encoded traversal in direct file references'
require_case 'test/core/services/skills/github_skill_ref_phase13e_test.dart' 'accepts ordinary dotted and percent-encoded filenames'
require_case 'test/core/services/skills/skill_pack_independent_members_phase13e_test.dart' 'pack creation and activation never overwrite standalone Skill state'
require_case 'test/core/services/skills/skill_pack_independent_members_phase13e_test.dart' 'manual Skill Packs never take ownership of member updates'
require_case 'test/core/services/skills/skill_pack_independent_members_phase13e_test.dart' 'editing Pack membership never moves or deletes original Skills'
require_case 'test/features/home/services/file_upload_any_attachment_phase13e_test.dart' 'device picker accepts any extension without loading all bytes into RAM'
require_case 'test/core/services/skills/skill_pack_independent_members_phase13e_test.dart' 'one original Skill can belong to multiple independent packs'
require_case 'test/core/services/extensions/conversational_extension_service_test.dart' 'extension list preserves original Skill status and reports pack membership separately'
require_case 'test/features/workspace/skills/skill_pack_original_visibility_phase13e_test.dart' 'Skills page shows pack members as original standalone rows'
require_case 'test/features/workspace/skills/skill_pack_original_visibility_phase13e_test.dart' 'conversation selector lists a pack member independently'

# GitHub URL path-traversal protection must inspect the original path before
# Uri parsing can normalize literal dot segments. Keep both negative and
# positive regression cases in the active Phase 13E lane.
python3 - <<'PY_GITHUB_PATH'
from pathlib import Path
source = Path('lib/core/services/skills/github_skill_ref.dart').read_text(encoding='utf-8')
parse_start = source.index('static GitHubSkillRef? tryParse(String raw)')
parse_end = source.index('GitHubSkillRef _validated()', parse_start)
parse_body = source[parse_start:parse_end]
if parse_body.index('_hasUnsafeRawPathSegments(text)') > parse_body.index('Uri.tryParse(text)'):
    raise SystemExit('FAIL: raw GitHub path validation must run before Uri.tryParse')
helper_start = source.index('bool _hasUnsafeRawPathSegments(String value)')
helper_end = source.index('bool _isSafeRepositoryPart(String value)', helper_start)
helper = source[helper_start:helper_end]
for token in ('%25', '%2e', '%2f', '%5c', '%00'):
    if token not in helper:
        raise SystemExit(f'FAIL: traversal decoder is missing {token}')
print('PASS: GitHub raw-path traversal guard precedes URI normalization')
print('PASS: GitHub traversal decoder covers double encoding and encoded separators')
PY_GITHUB_PATH

# Skill Packs are non-destructive references. Their membership must not hide,
# move, toggle or delete the original Skill records.
python3 - <<'PY_SKILL_PACK'
from pathlib import Path
import re
service = Path('lib/core/services/skills/skills_service.dart').read_text(encoding='utf-8')
pane = Path('lib/features/workspace/widgets/skills/skills_pane.dart').read_text(encoding='utf-8')
sheet = Path('lib/features/workspace/widgets/skills/conversation_skills_sheet.dart').read_text(encoding='utf-8')
detail = Path('lib/features/workspace/widgets/skills/skill_detail.dart').read_text(encoding='utf-8')
extensions = Path('lib/core/services/extensions/conversational_extension_service.dart').read_text(encoding='utf-8')

checks = [
    ('standalone Skill enable updates only the SkillRecord', re.search(
        r'Future<void> setEnabled\(String id, bool enabled\).*?final next = skill\.record\.copyWith\(\s*enabled: enabled,', service, re.S) is not None),
    ('pack save does not remove members from other packs',
        'Packs are non-destructive references to installed Skills' in service and 'nextPacks.add(pack)' in service),
    ('pack enable stores only pack metadata', re.search(
        r'Future<void> setSkillPackEnabled\(String id, bool enabled\).*?final next = _skillPacks\[index\]\.copyWith\(\s*enabled: enabled,', service, re.S) is not None),
    ('pack deletion does not delete Skill records', re.search(
        r'Future<void> deleteSkillPack\(String id\).*?store\.delete\(ExtensionEntityStore\.kindSkillPack, id\);\s*_skillPacks\.removeWhere', service, re.S) is not None),
    ('manual Packs do not advertise bulk update', re.search(
        r'bool canUpdateSkillPack\(String packId\).*?if \(pack == null \|\| !pack\.autoDetected', service, re.S) is not None),
    ('manual Packs cannot invoke repository-wide update', re.search(
        r'Future<List<Skill>> updateSkillPack\(.*?if \(!pack\.autoDetected\) throw StateError\(\'skill_pack_not_repository_group\'\)', service, re.S) is not None),
    ('update all groups only repository-detected packs', re.search(
        r'for \(final pack in List<SkillPack>\.from\(\s*_skillPacks\.where\(\(item\) => item\.autoDetected\)', service, re.S) is not None),
    ('Skills page does not filter pack members out of originals',
        'final filtered = _filtered(skills);' in pane and 'groupedIds' not in pane),
    ('conversation selector lists every original Skill independently',
        'final listed = skillsService.skills.toList(growable: false);' in sheet and 'groupedSkillIds' not in sheet),
    ('Skill detail retains its independent enabled switch',
        'service.setEnabled(skill.record.id, value)' in detail and '_SkillEnabledSwitch' in detail),
    ('explicit selection of one Skill does not expand to a pack',
        'explicitlyAllowed.contains(skill.record.id)' in service and 'groupedIds' not in service),
    ('extension_list reports each original Skill standalone state',
        "'standalone: ${skill.record.enabled ? 'enabled' : 'disabled'}; '" in extensions),
    ('extension_list filters by each Skill standalone switch',
        "'enabled' => skill.record.enabled" in extensions and "'disabled' => !skill.record.enabled" in extensions),
    ('extension_list reports effective availability separately',
        'final enabledByPack = memberPacks.any((pack) => pack.enabled);' in extensions and "'effective: $effectiveLabel; '" in extensions),
    ('extension_list displays Skill Packs in a separate section',
        "..writeln('## Skill Packs')" in extensions and 'final listedIds = <String>{}' not in extensions),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: Skill Pack independence guard: {label}')
    print(f'PASS: {label}')
PY_SKILL_PACK

# Keep direct GitHub ZIP imports on the same content-based route used by the
# application: one Skill ZIP is a repository Skill archive; a ZIP containing
# nested Skill ZIPs is a multi-Skill package. Never call the nested-only helper
# directly for a regular Skill ZIP.
python3 - <<'PYGITHUBZIP'
from pathlib import Path
import re

path = Path('test/core/services/skills/skill_bundle_import_phase13e_test.dart')
source = path.read_text(encoding='utf-8')
cases = [
    ("test('imports the exact direct GitHub ZIP file as a complete Skill archive'", {
        'service import': 'service.importSkillsFromFile(',
        'GitHub snapshot extraction': 'extractGitHubRepositoryFile',
        'preview content route': 'service.inspectLocalSource(extractedPath)',
        'script companion': 'scripts/run.py',
        'reference companion': 'references/guide.md',
        'config companion': 'assets/config.json',
    }),
    ("test('imports a direct GitHub ZIP containing a nested multi-Skill package'", {
        'service import': 'service.importSkillsFromFile(',
        'GitHub snapshot extraction': 'extractGitHubRepositoryFile',
        'preview content route': 'service.inspectLocalSource(extractedPath)',
        'first nested Skill': 'Skills/alpha.zip',
        'second nested Skill': 'Skills/beta.zip',
        'package-level resource': 'Prompts.txt',
    }),
]
for marker, required in cases:
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f'FAIL: direct GitHub ZIP regression is missing: {marker}')
    next_test = source.find('\n  test(', start + len(marker))
    block = source[start: next_test if next_test >= 0 else len(source)]
    for label, snippet in required.items():
        if snippet not in block:
            raise SystemExit(f'FAIL: {marker} is missing {label}')
    if 'extractNestedSkillBundleArchive' in block:
        raise SystemExit(f'FAIL: {marker} bypasses content-based ZIP routing')
    if not re.search(r'service\.importSkillsFromFile\s*\(\s*extractedPath', block, re.S):
        raise SystemExit(f'FAIL: {marker} does not exercise SkillsService import')
print('PASS: direct GitHub single-Skill ZIP and nested multi-Skill ZIP both use SkillsService content-based routing')
PYGITHUBZIP
record 'PASS: direct GitHub ZIPs use content-based Skill archive routing.'

# Check the two tool-dispatch branches enforce fresh approval independently of
# the generic ToolCallPermission approval unit tests.
python3 - <<'PY'
from pathlib import Path
import re
source = Path('lib/features/home/services/tool_handler_service.dart').read_text(encoding='utf-8')
checks = {
    'package mutations': r'if\s*\(PackageManagerToolNames\.requiresManualApprovalActions\.contains\(action\)\)\s*\{\s*await permission\.authorize\((.*?)\);',
    'Skill management mutations': r'if\s*\(ExtensionCommandToolNames\.requiresManualApproval\.contains\(name\)\)\s*\{\s*await permission\.authorize\((.*?)\);',
}
for label, pattern in checks.items():
    match = re.search(pattern, source, re.S)
    if not match or 'requireManualApproval: true' not in match.group(1):
        raise SystemExit(f'FAIL: {label} dispatch does not force requireManualApproval: true')
    print(f'PASS: {label} force a fresh manual approval')
PY

grep -Fq 'flutter test --no-pub' .github/scripts/run_phase13e_tests.sh || fail 'Phase 13E runner must use flutter test --no-pub.'
if grep -Eq 'run_phase13[abcd]_|test/core/services/skills/skill_(archive|import_manifest|executor)_test\.dart' .github/scripts/run_phase13e_tests.sh; then
  fail 'Phase 13E runner unexpectedly includes historical Phase 13A–13D test targets.'
fi
python3 - <<'PY'
from pathlib import Path
workspace = Path('lib/core/services/workspace/workspace_tools_service.dart').read_text(encoding='utf-8')
context = Path('lib/core/services/workspace/workspace_tool_context.dart').read_text(encoding='utf-8')
message = Path('lib/features/home/services/message_generation_service.dart').read_text(encoding='utf-8')
handler = Path('lib/features/home/services/tool_handler_service.dart').read_text(encoding='utf-8')
if 'requireManualApproval: ctx.conversationScoped' not in workspace:
    raise SystemExit('FAIL: conversation-scoped shell can bypass manual approval')
if 'shellNeedsApproval: true' not in workspace:
    raise SystemExit('FAIL: conversation-scoped workspace does not default to shell approval')
if 'ctx.conversationScoped' not in workspace or 'ctx.workspace.isToolEnabled(name)' not in workspace:
    raise SystemExit('FAIL: ephemeral chat workspace tool enablement was not separated from project lookup')
if 'workspaceId: ctx.skillsOnly || ctx.conversationScoped' not in workspace:
    raise SystemExit('FAIL: synthetic chat workspace id leaks into the persisted conversation permission binding')
if 'if (ctx.skillsOnly || ctx.conversationScoped) return;' not in workspace:
    raise SystemExit('FAIL: scratch workspace still mutates persistent project binding metadata')
if "!status.ready || status.engine != 'proot' || !status.sandboxed" not in workspace:
    raise SystemExit('FAIL: private chat workspace can be created without a verified Android PRoot status')
if 'resolveConversationScoped' not in message:
    raise SystemExit('FAIL: unbound conversations do not resolve their private runtime workspace')
if 'assistantId: currentConversation?.assistantId,' not in message:
    raise SystemExit('FAIL: scratch workspace permission owner does not match the persisted conversation assistant id')
if 'workspaceContext.hasReadyProotRuntime' not in handler:
    raise SystemExit('FAIL: Skill execution tool is not gated on the verified sandboxed PRoot context')
if 'bool get hasReadyProotRuntime' not in context:
    raise SystemExit('FAIL: shared ready-PRoot context predicate is missing')
if 'Runtime connection: shell executes inside the installed Android PRoot guest' not in workspace:
    raise SystemExit('FAIL: model-facing prompt does not describe the live PRoot command bridge')
if 'final conversationProotReady = status?.ready == true' not in workspace:
    raise SystemExit('FAIL: Shell does not re-check the current PRoot runtime status at invocation time')
if 'includeRuntimeProfiles: !ctx.conversationScoped' not in workspace:
    raise SystemExit('FAIL: conversation workspaces still expose project Runtime Profile tools')
if 'if (includeRuntimeProfiles)' not in workspace:
    raise SystemExit('FAIL: Shell schema does not conditionally omit runtime_profile_id')
if 'if (!ctx.conversationScoped && profiles != null)' not in workspace:
    raise SystemExit('FAIL: conversation-scoped Shell still resolves project Runtime Profiles')
if 'final runtimeProfileIgnored = ctx.conversationScoped' not in workspace:
    raise SystemExit('FAIL: stale/model-invented Runtime Profile IDs are not isolated from chat workspaces')
if 'Runtime Profiles are project-scoped and unavailable here' not in workspace:
    raise SystemExit('FAIL: model prompt does not explain that chat workspaces use base PRoot')
focused = Path('test/core/services/sandbox/environment_status_tool_test.dart').read_text(encoding='utf-8')
for assertion in [
    "expect(toolNames, isNot(contains('runtime_profile')))",
    "expect(shellProperties.containsKey('runtime_profile_id'), isFalse)",
    "'runtime_profile_id': 'model-invented-missing-profile-id'",
    "expect(decoded['runtime_profile_ignored'], isTrue)",
]:
    if assertion not in focused:
        raise SystemExit(f'FAIL: focused conversation Runtime Profile regression is missing: {assertion}')
print('PASS: chat scratch workspaces use base PRoot without project Runtime Profiles; arbitrary profile IDs are ignored while per-command approval remains mandatory')
PY
record 'PASS: only Phase 13E tests are in the active lane; historical 13A–13D gates are excluded.'
