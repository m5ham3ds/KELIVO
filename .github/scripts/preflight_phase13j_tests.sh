#!/usr/bin/env bash
# Static checks for Phase 13J: information-first Skill environment requirements.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13J PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/skills/skill_requirements.dart \
  lib/core/services/skills/skill_import_manifest.dart \
  lib/core/services/skills/skill_composition_service.dart \
  lib/core/services/skills/skills_prompt.dart \
  lib/core/services/extensions/conversational_extension_service.dart \
  lib/features/workspace/widgets/skills/skill_import.dart \
  test/core/services/skills/skill_requirements_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart \
  test/core/services/skills/skills_service_test.dart \
  test/core/services/skills/skills_prompt_test.dart \
  .github/scripts/run_phase13j_tests.sh \
  .github/scripts/test_phase13j_ci.sh; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13J component: $file"
done

python3 - <<'PY_PHASE13J'
from pathlib import Path
analyzer = Path('lib/core/services/skills/skill_requirements.dart').read_text(encoding='utf-8')
manifest = Path('lib/core/services/skills/skill_import_manifest.dart').read_text(encoding='utf-8')
composition = Path('lib/core/services/skills/skill_composition_service.dart').read_text(encoding='utf-8')
prompt = Path('lib/core/services/skills/skills_prompt.dart').read_text(encoding='utf-8')
conversation = Path('lib/core/services/extensions/conversational_extension_service.dart').read_text(encoding='utf-8')
ui = Path('lib/features/workspace/widgets/skills/skill_import.dart').read_text(encoding='utf-8')
test = Path('test/core/services/skills/skill_requirements_test.dart').read_text(encoding='utf-8')
prompt_policy_test = Path('test/core/services/skills/skills_prompt_test.dart').read_text(encoding='utf-8')
prompt_policy = 'Do not claim a Skill was installed until its files have been saved and verified.'
checks = [
    ('uses the strict existing Skill YAML frontmatter parser', 'SkillFrontmatter.parse(skillMarkdown)' in analyzer),
    ('discovers command line tools from bounded inspected text', '_knownCommands' in analyzer and 'inspectedTextFiles.entries' in analyzer),
    ('discovers required toolchains and interpreter extensions', '_extensionInterpreters' in analyzer and '_runtimeToolchainLabels' in analyzer),
    ('infers runtimes from dependency ecosystems', "'python' => 'python3'" in analyzer and "'node' => 'node'" in analyzer and "'rust' => 'cargo'" in analyzer),
    ('discovers API and cloud credential names without retaining values', 'ACCESS_KEY_ID|CLIENT_ID|CLIENT_SECRET|BASE_URL|ENDPOINT|URL|USERNAME|APPLICATION_CREDENTIALS' in analyzer and 'secretValuesExtractedOrReturned' in analyzer),
    ('indexes dependency declarations and manager support gaps', "'not_supported_by_current_package_manager'" in analyzer and "'not_checked_in_skill_profile'" in analyzer),
    ('parses explicit package install declarations without execution', 'explicit install command' in analyzer and 'not executed' in analyzer and 'installPatterns' in analyzer),
    ('detects variable names without reading secret values', 'environment.variables.map((item) => item.name)' in analyzer and 'secretValuesExtractedOrReturned' in analyzer),
    ('inventories external hosts without contacting them', "'verification': 'not_contacted'" in analyzer and 'no external API was called' in analyzer),
    ('probes only allowlisted command names with command -v', "command -v '$name'" in analyzer and "RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$')" in analyzer),
    ('import manifest persists static requirement analysis', 'SkillRequirementsAnalyzer.analyze(' in manifest and 'requirements: Map.unmodifiable(requirementReport)' in manifest),
    ('scans bounded environment and deployment manifests and reports skipped oversized text files', "'.env.example'" in manifest and '256 KiB per-file inspection limit' in manifest),
    ('composition returns requirement inventories for selected Skills', 'selectedSkillRequirements' in composition and "'requirementPolicy'" in composition),
    ('install and inspect return a live requirement assessment', '_requirementsAssessment(importReport)' in conversation and 'SkillEnvironmentRequirementProbe.toMarkdown(requirements)' in conversation),
    ('import UI displays Arabic requirement report', 'arabic: isArabic' in ui and 'SkillEnvironmentRequirementProbe.toMarkdown' in ui),
    ('assistant is instructed to inspect requirements before using capabilities', 'Skill environment requirement discovery is mandatory' in prompt and 'extension_inspect' in prompt),
    ('assistant must not auto-install packages or execute Skills during discovery', 'never install packages' in prompt and 'Never run Skill scripts' in prompt),
    ('prompt installation policy and regression assertion use the same verified wording', prompt_policy in prompt and prompt_policy in prompt_policy_test and 'never pretend it was installed' not in prompt_policy_test),
    ('no-requirement warning ignores instruction-only capability metadata and counts external services', 'hasRequirementEvidence' in analyzer and 'services.isNotEmpty' in analyzer and 'Instruction-only capability declarations are not environment requirement evidence' in analyzer and 'does not claim no requirements when an external service is declared' in test),
    ('regression tests cover discovery and non-execution behavior', 'discovers runtimes, commands, packages, credentials and external hosts' in test and 'skillScriptsExecuted' in test),
    ('legacy installed Skills can be re-analysed and their inventory persisted', 'getImportReportWithRequirements' in Path('lib/core/services/skills/skills_service.dart').read_text(encoding='utf-8') and 'rebuilds and persists requirement inventory for a legacy installed Skill' in Path('test/core/services/skills/skills_service_test.dart').read_text(encoding='utf-8')),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

for forbidden in ['Process.run(', 'Process.start(', 'installPackage(', 'http.get(', 'http.post(']:
    if forbidden in analyzer:
        raise SystemExit(f'FAIL: analyzer contains a prohibited execution/network pattern: {forbidden}')
print('PASS: analyzer contains no Skill execution, package installation, or outbound HTTP calls')
PY_PHASE13J

bash -n .github/scripts/run_phase13j_tests.sh
bash -n .github/scripts/test_phase13j_ci.sh
echo 'Phase 13J static preflight passed.'
