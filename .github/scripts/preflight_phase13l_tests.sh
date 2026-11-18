#!/usr/bin/env bash
# Static preflight for Phase 13L. Does not install dependencies or run Skills.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13L PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/skills/skill_requirements.dart \
  lib/core/services/skills/skill_readiness.dart \
  lib/core/services/skills/skill_import_manifest.dart \
  lib/core/services/skills/skills_prompt.dart \
  lib/core/services/skills/skill_composition_service.dart \
  lib/features/workspace/widgets/skills/skill_detail.dart \
  test/core/services/skills/skill_requirements_test.dart \
  test/core/services/skills/skill_import_manifest_test.dart \
  test/core/services/skills/skill_readiness_phase13l_test.dart \
  .github/scripts/run_phase13l_tests.sh \
  .github/scripts/test_phase13l_ci.sh \
  phases/PHASE-13L-RUNTIME-PROFILE-INTEGRITY-AND-SKILL-EXECUTION-VALIDATION-AR.md; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13L component: $file"
done

python3 - <<'PY_PHASE13L'
from pathlib import Path
req = Path('lib/core/services/skills/skill_requirements.dart').read_text(encoding='utf-8')
readiness = Path('lib/core/services/skills/skill_readiness.dart').read_text(encoding='utf-8')
manifest = Path('lib/core/services/skills/skill_import_manifest.dart').read_text(encoding='utf-8')
prompt = Path('lib/core/services/skills/skills_prompt.dart').read_text(encoding='utf-8')
composition = Path('lib/core/services/skills/skill_composition_service.dart').read_text(encoding='utf-8')
detail = Path('lib/features/workspace/widgets/skills/skill_detail.dart').read_text(encoding='utf-8')
req_test = Path('test/core/services/skills/skill_requirements_test.dart').read_text(encoding='utf-8')
manifest_test = Path('test/core/services/skills/skill_import_manifest_test.dart').read_text(encoding='utf-8')
readiness_test = Path('test/core/services/skills/skill_readiness_phase13l_test.dart').read_text(encoding='utf-8')
runner = Path('.github/scripts/run_phase13l_tests.sh').read_text(encoding='utf-8')
checks = [
    ('Markdown requirement scanning considers executable excerpts instead of ordinary prose', '_markdownExecutableText(text)' in req and 'Only explicitly titled prerequisite sections' in req),
    ('GNU Make is discovered only from explicit tool wording or executable invocation', '_hasExplicitMakeInvocation(scanText)' in req and '_hasExplicitMakeRequirement(text)' in req and 'GNU\\s+Make' in req),
    ('Requirement evidence reports source path and line numbers', 'static String _lineEvidence' in req and "(prerequisites)" in req),
    ('Executable interpreter inference follows declared entry points', 'declaredEntryPoints.contains(path)' in req and "capability['entryPoints']" in req),
    ('Capability IDs and entry points survive into the requirement snapshot', "'id': descriptorId" in req and "'entryPoints': rawEntryPoints" in req and "'requiredForReadiness':" in req),
    ('Example, sample, test and asset source files are not auto-classified as runnable scripts', '_isImplicitRunnableScript' in manifest and 'referenceOnlyDirectories' in manifest and "'examples'" in manifest and "'assets'" in manifest),
    ('Readiness exposes Guidance, Execution and Fully Ready as separate levels', all(token in readiness for token in ['ready_for_guidance', 'ready_for_execution', 'fully_ready', 'readinessLevelLabel'])),
    ('Execution readiness requires a verified Skill-owned profile and per-capability evidence', "profileVerification['profileId'] is String" in readiness and 'passedCapabilityIds' in readiness and "_hasEvidence(entry.value['evidence'])" in readiness),
    ('Fully Ready requires an overall passed validation and all mandatory capability evidence', 'final fullyValidated = executionReady && validated && mandatoryCapabilitiesPassed' in readiness),
    ('Composition and assistant prompts do not overstate partial capability readiness', 'Only readinessLevel=fully_ready' in composition and 'ready_for_execution' in prompt and 'ready_for_guidance' in prompt),
    ('Skill details UI presents the three readiness levels', all(token in detail for token in ['جاهزة بالكامل', 'جاهزة للتنفيذ للقدرات المختبرة فقط', 'جاهزة للإرشاد'])),
    ('Tests cover prose false positives, line evidence, preserved capability identity and browser examples', 'does not infer GNU make from ordinary Markdown prose and reports line evidence' in req_test and 'does not infer commands from JavaScript example assets' in req_test and 'keeps capability identity and entrypoint evidence' in req_test and 'browser example scripts are preserved but are not implicit Node entrypoints' in manifest_test),
    ('Tests cover guidance, partial execution, full readiness and profile evidence', all(token in readiness_test for token in ['Ready for Guidance', 'Ready for Execution', 'Fully Ready', 'base PRoot detection cannot substitute'])),
    ('Phase 13L runner executes all focused test files', all(token in runner for token in ['skill_requirements_test.dart', 'skill_import_manifest_test.dart', 'skill_readiness_phase13l_test.dart'])),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

# A discovery module must never perform package installation, script execution,
# or network calls as part of static requirement analysis.
for forbidden in ['Process.run(', 'Process.start(', 'installPackage(', 'http.get(', 'http.post(']:
    if forbidden in req:
        raise SystemExit(f'FAIL: requirement discovery contains prohibited side effect: {forbidden}')
print('PASS: requirement discovery remains read-only')
PY_PHASE13L

bash -n .github/scripts/run_phase13l_tests.sh
bash -n .github/scripts/test_phase13l_ci.sh
echo 'Phase 13L static preflight passed.'
