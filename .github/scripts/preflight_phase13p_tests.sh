#!/usr/bin/env bash
# Static preflight for Phase 13P. It inspects test wiring only; the Android
# integration test is the only place where the deterministic fixture Skill runs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13P PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  integration_test/workspace/skill_execution_e2e_test.dart \
  .github/scripts/run_phase13p_tests.sh \
  .github/scripts/run_phase13p_android_e2e.sh \
  .github/scripts/test_phase13p_ci.sh \
  phases/PHASE-13P-END-TO-END-SKILL-TESTING-AR.md; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13P component: $file"
done

python3 - <<'PY_PHASE13P'
from pathlib import Path

test = Path('integration_test/workspace/skill_execution_e2e_test.dart').read_text(encoding='utf-8')
executor = Path('lib/core/services/skills/skill_executor.dart').read_text(encoding='utf-8')
profile_service = Path('lib/core/services/runtime_profiles/runtime_profile_service.dart').read_text(encoding='utf-8')
background = Path('lib/core/services/mobile_background.dart').read_text(encoding='utf-8')
workflow = Path('.github/workflows/android-build.yml').read_text(encoding='utf-8')
runner = Path('.github/scripts/run_phase13p_tests.sh').read_text(encoding='utf-8')
android_runner = Path('.github/scripts/run_phase13p_android_e2e.sh').read_text(encoding='utf-8')
report = Path('phases/PHASE-13P-END-TO-END-SKILL-TESTING-AR.md').read_text(encoding='utf-8')

checks = [
    ('E2E imports a real ZIP through SkillsService and validates the persisted import manifest', all(token in test for token in ['skills.importFromFile(zipFile.path)', 'getImportReport(', "importReport['completeness']", "item['kind'] == 'local_script'", "'scripts/run.sh'"])),
    ('E2E creates a Skill-owned Runtime Profile and verifies the actual Profile PATH', all(token in test for token in ['RuntimeProfileScope.extension', 'ownerId: skill.record.id', 'RuntimeProfileEcosystem.shell', 'inspectSkillProfileCommands', "commandNames: const ['bash']", "profileCheck['status']"])),
    ('E2E dispatches through SkillExecutor with a one-run approval grant and pinned source digest', all(token in test for token in ['SkillExecutionPermissionPolicy.approveForSingleRun', 'executionGrantId: grantId', 'selectedSourceDigests:', 'sharedRootfsRiskAcknowledged: true', 'executor.execute(', r"^sha256:[a-f0-9]{64}$"])),
    ('E2E script creates a declared JSON output and executor verifies the artifact media type and digest', all(token in test for token in ["expectedOutputs: const {'result': 'result.json'}", "expectedOutputTypes: const {'result': 'application/json'}", "outputs.single['sha256']", 'sha256.convert(outputBytes).toString()'])),
    ('E2E opens the result through the in-app read_file workspace tool and checks the payload', all(token in test for token in ["'read_file'", 'ClientToolResult.fromHandler(opened).content', "openedJson['skillId']", "['marker']", "'phase13p-verified'"])),
    ('E2E asserts execution ledger completion and active-task / foreground-service shutdown', all(token in test for token in ['kindSkillExecutionLedger', "['status'],\n          'succeeded'", 'BackgroundTaskPhase.tool', "flag('foregroundServiceActive')", "values['activeTasks']", 'BackgroundTaskOutcome.completed'])),
    ('Background lifecycle coverage explicitly distinguishes backgrounding from force-stop', all(token in test for token in ['AppLifecycleState.inactive', 'AppLifecycleState.paused', 'AppLifecycleState.resumed']) and 'force-stop' in test and 'simulated' in test),
    ('Runtime Profile command discovery uses the existing evidence API and never installs packages', 'inspectSkillProfileCommands' in profile_service and 'command -v' in profile_service and not any(token in test for token in ['apt install', 'apt-get install', 'apk add', 'pip install', 'npm install'])),
    ('E2E ZIP folder matches the normalized Skill name slug', 'phase-13p-e2e-verification/SKILL.md' in test and 'name: Phase 13P E2E Verification' in test),
    ('E2E remains a generic fixture and does not name any of the six supplied Skills', not any(sample in test.lower() for sample in ['ig-profile', 'ig-reel', 'ig-viral', 'animation-director', 'arabian-motion-video-director', 'character-visual-director'])),
    ('Focused Phase 13P unit runner covers import, executor, profile and background regressions', all(token in runner for token in ['skill_executor_test.dart', 'skill_execution_permissions_test.dart', 'skills_service_test.dart', 'runtime_profile_service_test.dart', 'mobile_background_test.dart'])),
    ('Android device runner prepares a Debug registrant before launching integration_test', all(token in android_runner for token in ['flutter build apk --debug --config-only', 'integration_test/workspace/skill_execution_e2e_test.dart', 'adb devices'])),
    ('Workflow wires the Phase 13P syntax, self-test, preflight, unit lane and Android emulator lane', all(token in workflow for token in ['phase13p_syntax_preflight', 'phase13p_ci_self_test', 'phase13p_preflight', 'phase13p_tests', 'phase13p_android_e2e', 'run_android_skill_e2e'])),
    ('Android emulator E2E runs on every main push, remains manually selectable, and has a clean PRoot install budget', all(token in workflow for token in ["default: false", "github.event_name == 'push'", "github.ref == 'refs/heads/main'", "github.event_name == 'workflow_dispatch'", 'api-level: 35', 'arch: x86_64', 'timeout-minutes: 90', 'timeout-minutes: 300'])),
    ('Build reports preserve the Phase 13P skip and main-push/manual E2E outcomes', all(token in Path('.github/scripts/record_skipped_build_stages.sh').read_text(encoding='utf-8') for token in ['phase13p_syntax_preflight', 'phase13p_ci_self_test', 'phase13p_preflight', 'phase13p_tests', 'phase13p_android_e2e']) and all(token in Path('.github/scripts/generate_build_report.py').read_text(encoding='utf-8') for token in ['phase13p_syntax_preflight', 'phase13p_android_e2e'])),
    ('Documentation explains limits and manual Android device execution', all(token in report for token in ['Force Stop', 'PRoot', 'integration_test', 'flutter test', 'إذن الإشعارات'])),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

# Test fixture names must remain generic, and only the test fixture may contain
# the phrase PHASE13P_E2E_DONE as a deterministic success marker.
for filename in [
    'lib/core/services/skills/skill_executor.dart',
    'lib/core/services/skills/skill_execution_permissions.dart',
    'lib/core/services/runtime_profiles/runtime_profile_service.dart',
    'lib/core/services/mobile_background.dart',
]:
    content = Path(filename).read_text(encoding='utf-8').lower()
    if 'phase13p-e2e' in content or 'phase13p_e2e_done' in content:
        raise SystemExit(f'FAIL: product runtime code is coupled to the test fixture: {filename}')
print('PASS: runtime execution remains generic and is not coupled to the E2E fixture')
PY_PHASE13P

bash -n .github/scripts/preflight_phase13p_tests.sh
bash -n .github/scripts/run_phase13p_tests.sh
bash -n .github/scripts/run_phase13p_android_e2e.sh
bash -n .github/scripts/test_phase13p_ci.sh

echo 'Phase 13P static preflight passed.'
