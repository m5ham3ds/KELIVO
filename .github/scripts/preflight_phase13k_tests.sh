#!/usr/bin/env bash
# Static checks for Phase 13K: staged Skill readiness and app-wide capability registry.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13K PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/skills/skill_capability_registry.dart \
  lib/core/services/skills/skill_readiness.dart \
  lib/core/services/skills/skill_requirements.dart \
  lib/core/services/skills/skills_service.dart \
  lib/core/services/skills/skill_composition_service.dart \
  lib/core/services/skills/skills_prompt.dart \
  lib/core/services/extensions/conversational_extension_service.dart \
  lib/features/workspace/widgets/skills/skill_detail.dart \
  lib/features/workspace/widgets/skills/skill_import.dart \
  test/core/services/skills/skill_readiness_phase13k_test.dart \
  test/features/workspace/skills/skill_catalog_arabic_localization_phase13k_test.dart \
  test/core/services/skills/skills_service_test.dart \
  test/core/services/skills/skills_prompt_test.dart \
  .github/scripts/run_phase13k_tests.sh \
  .github/scripts/test_phase13k_ci.sh; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13K component: $file"
done

python3 - <<'PY_PHASE13K'
from pathlib import Path
registry = Path('lib/core/services/skills/skill_capability_registry.dart').read_text(encoding='utf-8')
readiness = Path('lib/core/services/skills/skill_readiness.dart').read_text(encoding='utf-8')
requirements = Path('lib/core/services/skills/skill_requirements.dart').read_text(encoding='utf-8')
service = Path('lib/core/services/skills/skills_service.dart').read_text(encoding='utf-8')
composition = Path('lib/core/services/skills/skill_composition_service.dart').read_text(encoding='utf-8')
prompt = Path('lib/core/services/skills/skills_prompt.dart').read_text(encoding='utf-8')
conversation = Path('lib/core/services/extensions/conversational_extension_service.dart').read_text(encoding='utf-8')
detail = Path('lib/features/workspace/widgets/skills/skill_detail.dart').read_text(encoding='utf-8')
ui = Path('lib/features/workspace/widgets/skills/skill_import.dart').read_text(encoding='utf-8')
ui_test = Path('test/features/workspace/skills/skill_catalog_arabic_localization_phase13k_test.dart').read_text(encoding='utf-8')
runner = Path('.github/scripts/run_phase13k_tests.sh').read_text(encoding='utf-8')
test = Path('test/core/services/skills/skill_readiness_phase13k_test.dart').read_text(encoding='utf-8')
checks = [
    ('Capability Registry is application-wide and independent from installed Skill ownership', 'kelivo.skill-capabilities' in registry and 'installedSkillsDoNotCreateApplicationCapabilities' in registry),
    ('Registry distinguishes generic, Python, Shell and Node script runtimes', all(x in registry for x in ['agent_skill.local_scripts', 'agent_skill.local_scripts.python', 'agent_skill.local_scripts.shell', 'agent_skill.local_scripts.node']) and "if (entryPoints.isEmpty)" in registry),
    ('Registry classifies MCP, HTTP, workflow and native adapters separately', all(x in registry for x in ['agent_skill.mcp_server', 'agent_skill.http_api_connector', 'agent_skill.workflow', 'agent_skill.native_kelivo_tool'])),
    ('Readiness is staged from install through validation', all(x in readiness for x in ['installed', 'analyzed', 'dependenciesResolved', 'configured', 'validated', 'readinessState'])),
    ('Full readiness requires a passed validation record', "validation['status'] == 'passed'" in readiness and "'validatedAt'" in readiness and "'evidence'" in readiness),
    ('Base PRoot command discovery is not treated as Skill profile dependency resolution', 'verifiedIn' in readiness and 'Skill-owned Runtime Profile' in readiness and 'commandsDetectedInBase' in readiness),
    ('CLI capability entrypoints match command evidence by executable basename', "if (kind == 'cli_binary')" in registry and "normalizedEntry.split('/').last" in registry and 'commandByName[commandName]' in registry),
    ('Instruction-only readiness never implies executable readiness', 'ready_for_instructions' in readiness and 'instructionOnly' in readiness),
    ('Unknown Skill capabilities fail closed instead of becoming Ready', "'unknown'," in readiness and 'unknownCapabilities' in readiness),
    ('Unknown local script entrypoints are not guessed to be Python', "'unclassifiedEntryPoints'" in registry and "if (ids.isEmpty) return const []" in registry),
    ('Unknown entrypoints are reflected in readiness counts', 'reportedUnknownCapabilityCount' in readiness and 'unknownRegistryCapabilityCount' in readiness),
    ('Runtime profile evidence requires non-empty profile identity and validation timestamp', "profileVerification['profileId'] is String" in registry and "profileVerification['validatedAt'] is String" in registry and "(profileVerification['profileId'] as String).trim().isNotEmpty" in readiness),
    ('Requirement probe applies readiness and capability registry', 'SkillReadinessEngine.apply(' in requirements and 'capabilityRegistry' in readiness),
    ('Readiness assessment persists with current source digest', 'saveEnvironmentAssessment' in service and "..['sourceDigest'] = sourceDigest" in service),
    ('Readiness persistence requires and matches the assessed source digest', 'skill_assessment_source_digest_required' in service and 'skill_source_changed_during_readiness_check' in service),
    ('Changed Skill inventory invalidates old environment assessment', "upgraded.remove('environmentAssessment')" in service),
    ('Editing SKILL.md invalidates readiness, requirement inventory and source digest', "..['readinessInvalidatedAt']" in service and "..remove('environmentAssessment')" in service and "..remove('requirementInventorySourceDigest')" in service and "..remove('sourceDigest')" in service),
    ('Composition exposes selected Skill readiness and app-wide capability registry', 'selectedSkillReadiness' in composition and 'SkillCapabilityRegistry.catalogJson()' in composition),
    ('Composition requires an environment re-check before executable use', 'environmentMustBeRecheckedBeforeExecution' in composition and 'passed Skill-specific validation' in composition),
    ('Assistant prompt distinguishes instruction readiness from operational readiness', '`ready_for_instructions` means the assistant may use written guidance only' in prompt),
    ('Install and inspect paths persist readiness snapshots', 'saveEnvironmentAssessment' in conversation),
    ('Skill detail exposes manual readiness refresh and full report', '_SkillReadinessPanel' in detail and 'Check readiness' in detail and 'Full report' in detail),
    ('Skill detail exposes the complete application-wide capability catalog', '_showCapabilityRegistry' in detail and 'SkillCapabilityRegistry.catalogJson()' in detail),
    ('Tests cover registry, generic script declarations, CLI command evidence, readiness stages and false-ready prevention', all(x in test for x in ['ready_for_instructions', 'dependencies_pending', 'unsupported_environment', 'stale_source', 'render.bin', 'generic local script declarations remain conditional', 'CLI entrypoint paths match command evidence', 'CLI runtime evidence is not trusted without profile identity'])),
    ('Skills catalog search declares Arabic locale in its own function scope', "Future<void> showSkillsCatalogSearch(BuildContext context) async {" in ui and "final isArabic = languageCode == 'ar';" in ui and "isArabic ? 'إغلاق' : 'Close'" in ui),
    ('Arabic Skills catalog close action has a focused widget regression', "skills catalog search dialog renders the Arabic close action" in ui_test and "expect(find.text('إغلاق'), findsOneWidget)" in ui_test and 'skill_catalog_arabic_localization_phase13k_test.dart' in runner),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

for forbidden in ['Process.run(', 'Process.start(', 'installPackage(', 'http.get(', 'http.post(']:
    if forbidden in readiness or forbidden in registry:
        raise SystemExit(f'FAIL: registry/readiness logic contains prohibited execution/network pattern: {forbidden}')
print('PASS: capability/readiness logic performs no Skill execution, installation, or network calls')
PY_PHASE13K

bash -n .github/scripts/run_phase13k_tests.sh
bash -n .github/scripts/test_phase13k_ci.sh
echo 'Phase 13K static preflight passed.'
