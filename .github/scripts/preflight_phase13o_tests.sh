#!/usr/bin/env bash
# Static and policy preflight for Phase 13O. This scan never executes Skill code,
# package managers, MCP servers or external services.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13O PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/skills/skill_doctor_service.dart \
  lib/core/services/runtime_profiles/runtime_profile_service.dart \
  lib/features/workspace/pages/skill_doctor_page.dart \
  lib/features/workspace/pages/skills_page.dart \
  lib/features/workspace/pages/skills_page_mobile_layout.dart \
  lib/features/workspace/pages/skills_page_desktop_layout.dart \
  lib/features/workspace/pages/workspace_settings_page.dart \
  test/core/services/skills/skill_doctor_policy_test.dart \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart \
  .github/scripts/run_phase13o_tests.sh \
  .github/scripts/test_phase13o_ci.sh \
  phases/PHASE-13O-SKILL-DOCTOR-AR.md; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13O component: $file"
done

python3 - <<'PY_PHASE13O'
from pathlib import Path

service = Path('lib/core/services/skills/skill_doctor_service.dart').read_text(encoding='utf-8')
profile_service = Path('lib/core/services/runtime_profiles/runtime_profile_service.dart').read_text(encoding='utf-8')
page = Path('lib/features/workspace/pages/skill_doctor_page.dart').read_text(encoding='utf-8')
policy_test = Path('test/core/services/skills/skill_doctor_policy_test.dart').read_text(encoding='utf-8')
profile_test = Path('test/core/services/runtime_profiles/runtime_profile_service_test.dart').read_text(encoding='utf-8')
workflow = Path('.github/workflows/android-build.yml').read_text(encoding='utf-8')
runner = Path('.github/scripts/run_phase13o_tests.sh').read_text(encoding='utf-8')
report = Path('phases/PHASE-13O-SKILL-DOCTOR-AR.md').read_text(encoding='utf-8')

checks = [
    ('Doctor is explicitly read-only and never invokes Skill entry points or package managers', all(token in service for token in ['read_only_diagnostics', 'skillEntryPointsExecuted\': false', 'packageManagersExecuted\': false', 'mcpServersStarted\': false', 'externalApisCalled\': false']) and not any(token in service for token in ['Process.start(', 'Process.run(', 'pip install', 'npm install', 'apt install', 'apk add'])),
    ('Doctor reads only credential names and never reads environment secret values', 'environment.variables.map((variable) => variable.name)' in service and 'variable.value' not in service and 'loadExecutionConfig(' not in service),
    ('Manifest integrity checks are bounded and verify SHA-256, file size, unsafe paths and symlinks', all(token in service for token in ['_maxManifestFiles', '_maxManifestBytes', '_maxFileBytes', 'sha256.bind(file.openRead())', 'sourceDigest', 'unsafe.add(relative)', 'FileSystemEntityType.link', 'untracked.add(relative)', 'file_integrity_check_failed'])),
    ('Shared repository resources are resolved in their preserved shared-resource root', all(token in service for token in ['sharedResources', 'repositories', 'sourcePath', "scope == 'shared'"])),
    ('Runtime Profiles are tied to extension scope and the owning Skill ID', all(token in service for token in ['RuntimeProfileScope.extension', 'profile.ownerId == skill.record.id', 'requiresRuntimeProfile'])),
    ('Runtime command checks use only bounded command -v probes in the exact Profile PATH', all(token in profile_service for token in ['inspectSkillProfileCommands', 'command -v', 'take(64)', 'Duration(seconds: timeout.inSeconds.clamp(1, 30).toInt())', '16 * 1024']) and 'inspectSkillProfileCommands' in service),
    ('Profile probes reject profile ownership mismatch before executing a command', all(token in profile_service for token in ['skill_runtime_profile_scope_mismatch', 'profile.ownerId != skillId']) and 'Skill Doctor rejects a Runtime Profile owned by another Skill' in profile_test),
    ('Readiness is not upgraded from file or command discovery alone', all(token in service for token in ['readinessRequirements({', "result.remove('runtimeProfileVerification')", 'validation: const <String, Object?>{}', 'isSafeCommandName'])),
    ('Global environment credentials are not treated as a Skill-scoped secret grant', all(token in service for token in ['configured_but_not_granted_to_skill', 'secret value was not read or injected'])),
    ('Generic capability kinds are inspected without hard-coding the six bundled Skill IDs', 'SkillCapabilityRegistry.assessRequirements' in service and all(token in report for token in ['generic', 'MCP', 'HTTP', 'Workflow', 'CLI'])),
    ('Only executable local_script and cli_binary kinds infer Runtime Profile ecosystems', all(token in service for token in ["if (kind == 'cli_binary')", "if (kind != 'local_script') continue;", "case '.py':", "case '.mjs':"]) and 'non-script capability kinds do not infer runtimes from referenced filenames' in policy_test),
    ('Recovery scope is explicit, skips only passed 13E-13N suites and preserves 13O/13P diagnostics', all(token in workflow for token in ['phase_test_scope', 'skill_doctor_recovery', 'phase13o_tests', 'phase13p_tests']) and "env.PHASE_TEST_SCOPE != 'skill_doctor_recovery'" in workflow),
    ('Doctor dashboard is reachable from the Skills and Workspace settings pages', all(token in page for token in ['SkillDoctorService', 'Profile command probe', 'openSkillDoctorPage', 'commands-invalid-name']) and all('openSkillDoctorPage' in Path(file).read_text(encoding='utf-8') for file in ['lib/features/workspace/pages/skills_page.dart', 'lib/features/workspace/pages/skills_page_mobile_layout.dart', 'lib/features/workspace/pages/skills_page_desktop_layout.dart', 'lib/features/workspace/pages/workspace_settings_page.dart'])),
    ('Policy tests cover instruction-only, local scripts, CLI, mixed runtimes and unknown adapters', all(token in policy_test for token in ['instruction-only', 'local_script', 'cli_binary', 'python', 'mjs', 'mcp_server', 'custom-vendor-agent-script', 'readiness assessment never reuses a previous Profile verification', 'command probe names reject shell metacharacters and paths'])),
    ('Profile tests cover command probe output, validated names and owner mismatch', all(token in profile_test for token in ['Skill Doctor probes only validated commands', 'bad;touch', 'skill_runtime_profile', 'foreign-profile'])),
    ('Focused Phase 13O CI includes policy, import-integrity, readiness and Runtime Profile regressions', all(token in runner for token in ['skill_doctor_policy_test.dart', 'runtime_profile_service_test.dart', 'skill_readiness_phase13l_test.dart', 'skill_import_manifest_test.dart'])),
    ('Workflow wires syntax, CI self-test, preflight and focused Phase 13O tests', all(token in workflow for token in ['phase13o_syntax_preflight', 'phase13o_ci_self_test', 'phase13o_preflight', 'phase13o_tests'])),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

# The universal Doctor must not be coupled to any of the six supplied examples.
example_ids = ['ig-profile', 'ig-reel', 'ig-viral', 'animation-director', 'arabian-motion-video-director', 'character-visual-director']
for filename in [
    'lib/core/services/skills/skill_doctor_service.dart',
    'lib/core/services/runtime_profiles/runtime_profile_service.dart',
    'lib/features/workspace/pages/skill_doctor_page.dart',
]:
    content = Path(filename).read_text(encoding='utf-8').lower()
    for example_id in example_ids:
        if example_id in content:
            raise SystemExit(f'FAIL: {filename} is hard-coded to bundled Skill {example_id}')
print('PASS: Skill Doctor and Profile probing remain independent of bundled Skill names')
PY_PHASE13O

bash -n .github/scripts/preflight_phase13o_tests.sh
bash -n .github/scripts/run_phase13o_tests.sh
bash -n .github/scripts/test_phase13o_ci.sh

echo 'Phase 13O static preflight passed.'
