#!/usr/bin/env bash
# Static checks for Phase 13F Skill composition and reusable chat attachments.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13F PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/skills/skill_composition_planner.dart \
  lib/core/services/skills/skill_composition_service.dart \
  lib/core/services/extensions/skill_composition_tools.dart \
  lib/core/services/extensions/skill_execution_tools.dart \
  lib/core/services/skills/skills_prompt.dart \
  lib/features/home/services/tool_handler_service.dart \
  lib/core/database/composer_draft_store.dart \
  lib/features/home/services/file_upload_service.dart \
  lib/features/home/widgets/chat_attachment_library_sheet.dart \
  lib/core/models/chat_attachment_library_item.dart \
  test/core/services/skills/skill_composition_phase13f_test.dart \
  test/features/home/widgets/chat_attachment_library_sheet_phase13f_test.dart \
  test/core/services/chat/chat_attachment_library_phase13f_test.dart \
  .github/scripts/run_phase13f_tests.sh; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13F component: $file"
done

# The tool schema must allow oversized/empty task text to reach the server-side
# latest-user-message fallback and compacting path.
python3 - <<'PY_PHASE13F_SCHEMA'
from pathlib import Path
compose = Path('lib/core/services/extensions/skill_composition_tools.dart').read_text(encoding='utf-8')
start = compose.index("'task': {")
end = compose.index("'mode': {", start)
task_schema = compose[start:end]
if "'maxLength': 8000" in task_schema or "'minLength': 1" in task_schema:
    raise SystemExit('FAIL: skill_compose schema still blocks oversized or empty task briefs before server-side normalization.')
if 'all_enabled' not in compose:
    raise SystemExit('FAIL: skill_compose schema does not expose all_enabled selection.')
planner = Path('lib/core/services/skills/skill_composition_planner.dart').read_text(encoding='utf-8')
for token in ('SkillCompositionMode.allEnabled', 'maxTaskCharacters = 8000', 'compactTaskBrief', 'skill_import_incomplete', 'skill_import_manifest_missing'):
    if token not in planner:
        raise SystemExit(f'FAIL: Skill planner is missing required Phase 13F behavior: {token}')
handler = Path('lib/features/home/services/tool_handler_service.dart').read_text(encoding='utf-8')
for token in ('latestUserText', 'loadRecentMessages', 'SkillCompositionMode.allEnabled', 'compactTaskBrief'):
    if token not in handler:
        raise SystemExit(f'FAIL: Skill composition handler is missing task recovery/selection behavior: {token}')
service = Path('lib/core/services/skills/skill_composition_service.dart').read_text(encoding='utf-8')
if 'getImportReport' not in service or "'unknown'" not in service:
    raise SystemExit('FAIL: Skill composition does not inspect the import completeness report.')
print('PASS: task schema allows server-side fallback/compaction; planner and handler expose all_enabled and completeness validation.')
PY_PHASE13F_SCHEMA

# Reuse of published uploads must preserve the shared path and library metadata.
python3 - <<'PY_PHASE13F_FILES'
from pathlib import Path
store = Path('lib/core/database/composer_draft_store.dart').read_text(encoding='utf-8')
upload = Path('lib/features/home/services/file_upload_service.dart').read_text(encoding='utf-8')
sheet = Path('lib/features/home/widgets/chat_attachment_library_sheet.dart').read_text(encoding='utf-8')
for token in ('publishedAttachments()', 'isPublishedFile', 'composerPublishedFile', '_legacyFilePartMetadata', 'p.isWithin(rootPath, absolutePath)', 'followLinks: false'):
    if token not in store:
        raise SystemExit(f'FAIL: attachment library store is missing: {token}')
for token in ('pickFilesFromDevice()', 'ChatAttachmentLibrarySheet.show', 'onUploadFromPhone: pickFilesFromDevice', 'publishedImages', 'copyFilePath'):
    if token not in upload:
        raise SystemExit(f'FAIL: file upload service is missing: {token}')
for token in ('final Set<String> _selected', 'onUploadFromPhone()', 'Navigator.of(context).pop(selectedItems)', 'chatAttachmentLibraryUploadFromFiles', 'chatAttachmentLibraryAdd'):
    if token not in sheet:
        raise SystemExit(f'FAIL: multi-select staged attachment sheet is missing: {token}')
print('PASS: reusable library filters to app-owned regular files and the picker stages/selects multiple files before Add.')
PY_PHASE13F_FILES

for test_file in \
  test/core/services/skills/skill_composition_phase13f_test.dart \
  test/features/home/widgets/chat_attachment_library_sheet_phase13f_test.dart \
  test/core/services/chat/chat_attachment_library_phase13f_test.dart; do
  grep -Fq "Phase 13F" "$test_file" || [[ "$test_file" == *chat_attachment_library_sheet_phase13f_test.dart || "$test_file" == *chat_attachment_library_phase13f_test.dart ]] \
    || fail "Phase 13F test file does not identify its coverage: $test_file"
done

# Never reintroduce the already-approved historical 13A–13D suites.
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' .github/workflows/android-build.yml .github/scripts/run_phase13f_tests.sh; then
  fail 'The active Android build or Phase 13F runner re-enables a historical 13A–13D test suite.'
fi
bash -n .github/scripts/run_phase13f_tests.sh

echo 'Phase 13F static preflight passed.'
