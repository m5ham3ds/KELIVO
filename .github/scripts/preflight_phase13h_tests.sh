#!/usr/bin/env bash
# Static checks for Phase 13H ZIP attachment recognition and workspace routing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13H PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/chat/document_text_extractor.dart \
  lib/core/utils/multimodal_input_utils.dart \
  lib/features/home/widgets/chat_input_bar.dart \
  lib/core/services/workspace/host_file_tools.dart \
  lib/core/services/workspace/workspace_tools_service.dart \
  lib/features/home/services/message_builder_service.dart \
  test/core/services/chat/document_text_extractor_test.dart \
  test/features/home/services/file_upload_service_test.dart \
  test/features/home/services/message_builder_sandbox_files_test.dart \
  test/core/services/workspace/workspace_session_sync_test.dart \
  test/core/services/workspace/workspace_paths_test.dart \
  test/core/services/workspace/host_file_tools_test.dart \
  test/core/services/workspace/workspace_tools_service_test.dart \
  test/core/services/extensions/conversational_extension_service_test.dart \
  lib/core/services/extensions/conversational_extension_service.dart \
  .github/scripts/run_phase13h_tests.sh \
  .github/scripts/test_phase13h_ci.sh \
  .github/scripts/audit_android_only.sh; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13H component: $file"
done

python3 - <<'PY_PHASE13H'
from pathlib import Path
extractor = Path('lib/core/services/chat/document_text_extractor.dart').read_text(encoding='utf-8')
mime = Path('lib/core/utils/multimodal_input_utils.dart').read_text(encoding='utf-8')
input_bar = Path('lib/features/home/widgets/chat_input_bar.dart').read_text(encoding='utf-8')
host = Path('lib/core/services/workspace/host_file_tools.dart').read_text(encoding='utf-8')
tools = Path('lib/core/services/workspace/workspace_tools_service.dart').read_text(encoding='utf-8')
builder = Path('lib/features/home/services/message_builder_service.dart').read_text(encoding='utf-8')
extractor_tests = Path('test/core/services/chat/document_text_extractor_test.dart').read_text(encoding='utf-8')
upload_tests = Path('test/features/home/services/file_upload_service_test.dart').read_text(encoding='utf-8')
builder_tests = Path('test/features/home/services/message_builder_sandbox_files_test.dart').read_text(encoding='utf-8')
sync_tests = Path('test/core/services/workspace/workspace_session_sync_test.dart').read_text(encoding='utf-8')
paths_source = Path('lib/core/services/workspace/workspace_paths.dart').read_text(encoding='utf-8')
paths_tests = Path('test/core/services/workspace/workspace_paths_test.dart').read_text(encoding='utf-8')
host_tests = Path('test/core/services/workspace/host_file_tools_test.dart').read_text(encoding='utf-8')
tool_tests = Path('test/core/services/workspace/workspace_tools_service_test.dart').read_text(encoding='utf-8')
extension_tools = Path('lib/core/services/extensions/extension_command_tools.dart').read_text(encoding='utf-8')
extension_tests = Path('test/core/services/extensions/conversational_extension_service_test.dart').read_text(encoding='utf-8')
extension_service = Path('lib/core/services/extensions/conversational_extension_service.dart').read_text(encoding='utf-8')
phase13h_runner = Path('.github/scripts/run_phase13h_tests.sh').read_text(encoding='utf-8')
checks = [
    ('document extraction rejects archive extensions and MIME types before UTF-8 decoding', "archiveExtensions.contains(extension)" in extractor and "archiveMimes.contains(normalizedMime)" in extractor),
    ('document extraction detects ZIP signature even with a changed extension', '_hasZipSignature(prefix)' in extractor),
    ('DOCX keeps its dedicated extraction path', 'if (isDocx) return _extractDocxSync(path);' in extractor),
    ('document extractor regression covers ZIP and signature-only archive', 'ZIP archives are never sent through inline text extraction' in extractor_tests and 'download.bin' in extractor_tests),
    ('generic octet-stream archive attachments recover MIME from their filename', "if (name.endsWith('.zip')) return 'application/zip';" in mime and "lower.endsWith('.zip')) return 'application/zip'" in input_bar),
    ('upload test covers archive MIME recovery', "fileName: 'animation-director.zip'" in upload_tests and "'application/zip'" in upload_tests),
    ('message builder directs ZIP Skills to extension_install and keeps archive bytes out of prompt text', 'Skill ZIP is routed to workspace tools rather than prompt text' in builder_tests and 'Do NOT call list_dir' in builder_tests and 'call extension_install directly' in builder_tests),
    ('ZIP attachment sync regression asserts the /chat path exists', 'ZIP attachment sync exposes a real /chat file path' in sync_tests and "'/chat/attachments/animation-director.zip'" in sync_tests),
    ('nested chat mount is resolved before the workspace mount', paths_source.index('final chatRel = relativeToHostRoot(sessionHostDir, hostPath);') < paths_source.index('final workspaceRel = relativeToHostRoot(workspaceHostRoot, hostPath);')),
    ('nested session path regression is included', 'nested session host paths keep the dedicated /chat mount' in paths_tests),
    ('ZIP parsing uses the existing archive package and signature sniffing', "package:archive/archive_io.dart" in host and '_hasZipSignature(signature)' in host),
    ('ZIP inspection has archive, entry-count, expanded-size and member-size bounds', 'maxZipArchiveBytes' in host and 'maxZipEntryCount' in host and 'maxZipExpandedBytes' in host and 'maxZipMemberReadBytes' in host),
    ('ZIP member traversal is rejected', 'unsafe ZIP member path' in host and "part == '..'" in host),
    ('read_file schema exposes archive_entry', "'archive_entry':" in tools),
    ('list_dir ZIP compatibility path returns archive manifest', "'zip_attachment_missing'" in tools and "'format': 'zip'" in tools and "'archive': true" in tools),
    ('list_dir regression covers ZIP manifest and missing attachment guidance', 'list_dir redirects a ZIP path to its archive manifest' in tool_tests and 'missing ZIP attachment reports workspace sync guidance' in tool_tests),
    ('read_file returns a manifest instead of decoding ZIP bytes as text', "'archive': true" in tools and "'entries':" in tools),
    ('user prompt routes Skill ZIP installs directly to extension_install and forbids list_dir', 'Do NOT call list_dir on this archive file path' in builder and 'call extension_install directly' in builder and 'archive_entry' in builder),
    ('Host file ZIP tests cover manifest and member reads', 'readFile identifies ZIP archives and lists their members' in host_tests and "archiveEntry: 'SKILL.md'" in host_tests),
    ('extension_install tool documents direct attached-ZIP import', 'call extension_install directly' in extension_tools and '/chat/attachments/<filename>.zip' in extension_tools),
    ('extension service test installs a ZIP from the /chat attachment mount', 'installs an attached Skill ZIP from the conversation chat mount' in extension_tests and '/chat/attachments/animation-director.zip' in extension_tests),
    ('attached Skill ZIP fixture matches the Agent Skill folder name to SKILL.md name', 'final skillDirectory = directoryName ?? name;' in extension_tests and "ArchiveFile.string('$skillDirectory/SKILL.md'" in extension_tests),
    ('incompatible attached Skill ZIP reports frontmatter and directory validation details', 'No compatible Agent Skills were found in this source.' in extension_service and 'Check that each SKILL.md name matches its containing' in extension_service),
    ('mismatched attached Skill ZIP metadata regression is included in CI', 'rejects an attached Skill ZIP with mismatched folder metadata with actionable details' in extension_tests and 'rejects an attached Skill ZIP with mismatched folder metadata with actionable details' in phase13h_runner),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')
PY_PHASE13H

bash -n .github/scripts/run_phase13h_tests.sh

echo 'Phase 13H static preflight passed.'
