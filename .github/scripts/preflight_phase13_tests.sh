#!/usr/bin/env bash
# Fast mode performs targeted prerequisite/ordering checks. All modes require
# GTK/GLib host development files because `flutter test` runs resolved package
# build hooks for the Linux host. Extended mode adds full Dart analysis and a
# separate compile/link + Native Asset smoke test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
REPORT_DIR="${KELIVO_CI_REPORT_DIR:-$ROOT/build-report}"
STATE_FILE="${KELIVO_PHASE13_TEST_STATE_FILE:-$ROOT/.dart_tool/kelivo_phase13_test_state.tsv}"
EXTENDED="${KELIVO_EXTENDED_PHASE13_TESTS:-false}"
mkdir -p "$REPORT_DIR" "$(dirname "$STATE_FILE")"
rm -f "$STATE_FILE" "${STATE_FILE}.tmp."*
: > "$REPORT_DIR/phase13-test-preflight.txt"
RUN_TOKEN="${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-$(date +%s)-${RANDOM}"
export KELIVO_PHASE13_GATE_TOKEN="$RUN_TOKEN"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'KELIVO_PHASE13_GATE_TOKEN=%s\n' "$RUN_TOKEN" >> "$GITHUB_ENV"
fi

fail() {
  local message="$1"
  printf 'FAIL: %s\n' "$message" | tee -a "$REPORT_DIR/phase13-test-preflight.txt" >&2
  rm -f "$STATE_FILE"
  exit 1
}
record() {
  printf '%s\n' "$1" | tee -a "$REPORT_DIR/phase13-test-preflight.txt"
}
mark_preflight_passed() {
  printf 'token=%s\npreflight=passed\n' "$RUN_TOKEN" > "$STATE_FILE"
  record 'PASS: Phase 13A may start. 13B/13C/13D remain gated on preceding phase success.'
}

record 'KELIVO Phase 13A–13D preflight'
record "UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
record "Mode: $([[ "$EXTENDED" == "true" ]] && echo extended || echo fast-smoke)"

for command_name in flutter dart python3; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command is missing before Phase 13 checks: $command_name"
done
record "Flutter: $(flutter --version | sed -n '1p')"
record "Dart: $(dart --version 2>&1 | sed -n '1p')"

# This is not an optional desktop test. The app dependency graph includes
# super_clipboard/super_native_extensions, whose Dart build hook compiles a
# Linux host backend whenever `flutter test` runs on Ubuntu, regardless of
# which focused test files were selected. Prepare/check these packages before
# any Phase runner so a missing pkg-config module cannot fail inside 13A.
for command_name in pkg-config cc; do
  command -v "$command_name" >/dev/null 2>&1 \
    || fail "Required Linux host build command is missing before Flutter tests: $command_name"
done
for module in glib-2.0 gobject-2.0 gio-2.0 gtk+-3.0; do
  module_version="$(pkg-config --modversion "$module" 2>/dev/null)" \
    || fail "Missing Linux host dependency required by Flutter package hooks: $module"
  record "PASS: host pkg-config $module $module_version"
done
record 'PASS: Linux GTK/GLib host prerequisites are ready for all Flutter test modes.'

PACKAGE_CONFIG_JSON="${KELIVO_DART_PACKAGE_CONFIG:-$ROOT/.dart_tool/package_config.json}"
[[ -s "$PACKAGE_CONFIG_JSON" ]] || fail 'Dart package configuration is missing; flutter pub get must complete before preflight.'
if ! python3 - "$PACKAGE_CONFIG_JSON" <<'PY'
import json
import sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
names = {item.get('name') for item in payload.get('packages', []) if isinstance(item, dict)}
if 'flutter_test' not in names:
    print('FAIL: package_config is missing flutter_test.', file=sys.stderr)
    raise SystemExit(1)
print('PASS: Flutter test package configuration is present.')
PY
then
  fail 'Dart package configuration validation failed.'
fi

PHASE_RUNNERS=(
  '.github/scripts/run_phase13a_import_tests.sh'
  '.github/scripts/run_phase13b_executor_tests.sh'
  '.github/scripts/run_phase13c_workspace_environment_tests.sh'
  '.github/scripts/run_phase13d_execution_security_tests.sh'
)
TOTAL_TARGETS=0
for runner in "${PHASE_RUNNERS[@]}"; do
  [[ -s "$runner" ]] || fail "Missing Phase test runner: $runner"
  grep -Fq 'phase13_require_ready' "$runner" || fail "Runner has no phase-order guard: $runner"
  grep -Fq 'phase13_mark_passed' "$runner" || fail "Runner does not record successful completion: $runner"
  grep -Fq 'flutter test --no-pub' "$runner" || fail "Runner may resolve packages mid-phase; --no-pub is required: $runner"
  mapfile -t targets < <(grep -oE 'test/[A-Za-z0-9_./-]+_test\.dart' "$runner" | sort -u)
  ((${#targets[@]} > 0)) || fail "No declared test targets were found in $runner"
  for target in "${targets[@]}"; do
    [[ -s "$target" ]] || fail "Missing test target referenced by $runner: $target"
    TOTAL_TARGETS=$((TOTAL_TARGETS + 1))
  done
done
record "PASS: ${#PHASE_RUNNERS[@]} ordered runners and $TOTAL_TARGETS referenced test targets exist."

# Dart test semantics: --name accepts regular expressions (including `|`),
# while --plain-name is literal. Validate both the option and each expected case
# so a typo cannot produce a green preflight followed by "No tests ran".
python3 - "${PHASE_RUNNERS[@]}" <<'PYSELECTOR' || fail 'Phase 13 runner contains an invalid test-name selector.'
import re
import sys
from pathlib import Path

expected = {
    'run_phase13a_import_tests.sh': [
        'indexes hidden, nested, binary and executable source files without running them',
        'records shared resources as explicit separate references',
        'repository extractor preserves shared files, hidden files and binary assets',
    ],
    'run_phase13b_executor_tests.sh': [
        'executes only a declared script from a verified snapshot and records output',
        'rejects execution when the selected interpreter is not in the profile',
    ],
    'run_phase13c_workspace_environment_tests.sh': [
        'media preset installs FFmpeg and verifies both ffmpeg and ffprobe',
        'project Python operations inherit the workspace default Runtime Profile',
    ],
    'run_phase13d_execution_security_tests.sh': [
        'redacts environment-style credential names with prefixes and suffixes',
        'approval and execution reports disclose the shared writable RootFS',
        'missing, malformed and legacy grants never imply full access',
    ],
}

for raw in sys.argv[1:]:
    path = Path(raw)
    lines = path.read_text(encoding='utf-8').splitlines()
    or_selectors = []
    for number, line in enumerate(lines, 1):
        match = re.search(r"--(plain-name|name)\s+(['\"])(.*?)\2", line)
        if not match:
            continue
        option, _, expression = match.groups()
        if '|' in expression:
            if option == 'plain-name':
                print(f"FAIL: {path}:{number} uses --plain-name with OR alternatives; use --name.", file=sys.stderr)
                raise SystemExit(1)
            try:
                compiled = re.compile(expression)
            except re.error as error:
                print(f"FAIL: invalid --name expression in {path}:{number}: {error}", file=sys.stderr)
                raise SystemExit(1)
            or_selectors.append(compiled)

    expected_names = expected.get(path.name)
    if expected_names is None:
        print(f"FAIL: no smoke selector expectations are defined for {path.name}.", file=sys.stderr)
        raise SystemExit(1)
    if len(or_selectors) != 1:
        print(f"FAIL: expected exactly one OR-regex selector in {path}; found {len(or_selectors)}.", file=sys.stderr)
        raise SystemExit(1)
    selector = or_selectors[0]
    for case_name in expected_names:
        if selector.search(case_name) is None:
            print(f"FAIL: {path.name} selector does not select expected smoke case: {case_name}", file=sys.stderr)
            raise SystemExit(1)
    print(f"PASS: {path.name} regex selector selects all {len(expected_names)} expected named smoke cases.")

print('PASS: all Phase 13 fast-lane OR selectors use regex-capable --name.')
PYSELECTOR

# Enforce that 13D-only executor tests never leak into the earlier 13B gate.
grep -Fq -- '--exclude-tags=phase13d' .github/scripts/run_phase13b_executor_tests.sh \
  || fail 'Phase 13B runner must exclude phase13d-tagged tests.'
grep -Fq -- '--tags=phase13d' .github/scripts/run_phase13d_execution_security_tests.sh \
  || fail 'Phase 13D runner must select the tagged executor policy tests.'
grep -Fq 'phase13d:' dart_test.yaml \
  || fail 'dart_test.yaml does not declare the phase13d tag.'
UI_APPROVAL_TEST='Skill execution approval displays the shared PRoot RootFS risk'
grep -Fq "$UI_APPROVAL_TEST" test/features/chat/widgets/workspace_tool_ui_test.dart \
  || fail 'The extended Phase 13D approval UI test is missing or was renamed.'
D_TAG_COUNT="$(grep -c "tags: 'phase13d'" test/core/services/skills/skill_executor_test.dart || true)"
[[ "$D_TAG_COUNT" == '2' ]] || fail "Expected exactly two Phase 13D-tagged executor tests; found $D_TAG_COUNT."
record "PASS: fast lane covers 10 explicit named smoke cases plus $D_TAG_COUNT tagged Phase 13D executor policy cases (12 total)."

# Verify all targeted smoke cases exist. These compile the relevant source when
# Flutter runs them; the Android APK build subsequently compiles the app target.
require_case() {
  local file="$1"
  local title="$2"
  [[ -s "$file" ]] || fail "Missing smoke-test file: $file"
  grep -Fq "$title" "$file" || fail "Missing CI smoke case '$title' in $file"
  record "Smoke case verified: $file :: $title"
}
require_case 'test/core/services/skills/skill_import_manifest_test.dart' 'indexes hidden, nested, binary and executable source files without running them'
require_case 'test/core/services/skills/skill_import_manifest_test.dart' 'records shared resources as explicit separate references'
require_case 'test/core/services/skills/skill_archive_test.dart' 'repository extractor preserves shared files, hidden files and binary assets'
require_case 'test/core/services/skills/skill_executor_test.dart' 'executes only a declared script from a verified snapshot and records output'
require_case 'test/core/services/skills/skill_executor_test.dart' 'rejects execution when the selected interpreter is not in the profile'
require_case 'test/core/services/sandbox/environment_dependencies_test.dart' 'media preset installs FFmpeg and verifies both ffmpeg and ffprobe'
require_case 'test/core/services/packages/package_manager_service_test.dart' 'project Python operations inherit the workspace default Runtime Profile'
require_case 'test/core/services/skills/skill_execution_security_test.dart' 'redacts environment-style credential names with prefixes and suffixes'
require_case 'test/core/services/skills/skill_execution_security_test.dart' 'approval and execution reports disclose the shared writable RootFS'
require_case 'test/core/services/conversation_tool_permissions_test.dart' 'missing, malformed and legacy grants never imply full access'

if [[ "$EXTENDED" != "true" ]]; then
  record 'FAST MODE: no full-project Dart analysis, standalone Rust Native Asset smoke, or broad regression suites are run.'
  record 'GTK/GLib host prerequisites were still checked because the focused flutter test commands execute Linux package build hooks.'
  record 'The focused Phase 13A–13D smoke tests and Android ARM64 Release build remain mandatory.'
  record 'Full regression suites remain in test/ and can be enabled manually from workflow_dispatch.'
  mark_preflight_passed
  exit 0
fi

# Extended-only compiler/toolchain checks. GTK/GLib modules were already
# required and verified above for every Flutter test invocation.
for command_name in pkg-config cc cargo rustc; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Extended mode requires $command_name."
done
record "Rust: $(rustc --version)"
record "Cargo: $(cargo --version)"
record "C compiler: $(cc --version | sed -n '1p')"

for module in glib-2.0 gobject-2.0 gio-2.0 gtk+-3.0; do
  module_version="$(pkg-config --modversion "$module" 2>/dev/null)" \
    || fail "Missing Linux test-host pkg-config module: $module."
  record "pkg-config $module: $module_version"
done

GTK_SMOKE_DIR="$(mktemp -d)"
trap 'rm -rf "$GTK_SMOKE_DIR"' EXIT
cat > "$GTK_SMOKE_DIR/gtk_smoke.c" <<'C'
#include <gtk/gtk.h>
int main(void) { return gtk_get_major_version() < 3; }
C
read -r -a GTK_CFLAGS <<< "$(pkg-config --cflags gtk+-3.0)"
read -r -a GTK_LIBS <<< "$(pkg-config --libs gtk+-3.0)"
if ! cc "${GTK_CFLAGS[@]}" "$GTK_SMOKE_DIR/gtk_smoke.c" \
    -o "$GTK_SMOKE_DIR/gtk_smoke" "${GTK_LIBS[@]}"; then
  fail 'GTK/GLib compiler and linker smoke test failed.'
fi
record 'PASS: GTK/GLib headers and link libraries compile successfully.'

if ! python3 - "$PACKAGE_CONFIG_JSON" <<'PY'
import json
import sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
names = {item.get('name') for item in payload.get('packages', []) if isinstance(item, dict)}
missing = {'super_native_extensions', 'super_clipboard'} - names
if missing:
    print('FAIL: package_config is missing: ' + ', '.join(sorted(missing)), file=sys.stderr)
    raise SystemExit(1)
print('PASS: Native clipboard package configuration is present.')
PY
then
  fail 'Extended Native Asset package configuration is incomplete.'
fi

DEPENDENCY_GRAPH="$REPORT_DIR/phase13-pub-dependencies.json"
flutter pub deps --json > "$DEPENDENCY_GRAPH" \
  || fail 'flutter pub deps --json failed in extended mode.'
if ! python3 - "$DEPENDENCY_GRAPH" "$ROOT/pubspec.lock" <<'PY'
import json
import re
import sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
packages = payload.get('packages') or []
names = {item.get('name') for item in packages if isinstance(item, dict)}
required = {'flutter_test', 'super_native_extensions', 'super_clipboard'}
missing = required - names
if missing:
    print('FAIL: resolved dependency graph is missing: ' + ', '.join(sorted(missing)), file=sys.stderr)
    raise SystemExit(1)
lock = Path(sys.argv[2]).read_text(encoding='utf-8')
for package, expected in {
    'super_native_extensions': '0.10.0-dev.2',
    'super_clipboard': '0.10.0-dev.2',
}.items():
    match = re.search(rf'(?ms)^  {re.escape(package)}:\n(.*?)(?=^  [^ ]|\Z)', lock)
    version = re.search(r'^    version: "?([^"\n]+)', match.group(1), re.MULTILINE) if match else None
    actual = version.group(1).strip() if version else 'unknown'
    if actual != expected:
        print(f'FAIL: {package} resolved to {actual}; expected {expected}.', file=sys.stderr)
        raise SystemExit(1)
print(f'PASS: {len(packages)} resolved packages and pinned Native Asset versions verified.')
PY
then
  fail 'Extended dependency graph or lockfile validation failed.'
fi

# Full Dart analysis is intentionally opt-in; its 27-file run previously took
# 144 seconds and duplicated compilation performed by focused tests/build.
PHASE13_TEST_FILES=(
  'test/core/services/skills/skill_archive_test.dart'
  'test/core/services/skills/skill_import_manifest_test.dart'
  'test/core/services/skills/skills_catalog_adapter_test.dart'
  'test/core/services/skills/skills_service_test.dart'
  'test/core/services/skills/skill_executor_test.dart'
  'test/core/services/runtime_profiles/runtime_profile_models_test.dart'
  'test/core/services/runtime_profiles/runtime_profile_service_test.dart'
  'test/core/services/tools/built_in_tool_catalog_test.dart'
  'test/core/services/packages/package_manager_service_test.dart'
  'test/core/services/sandbox/environment_dependencies_test.dart'
  'test/core/services/video_engines/video_engine_service_safety_test.dart'
  'test/core/services/conversation_tool_permissions_test.dart'
  'test/core/services/skills/skill_execution_security_test.dart'
  'test/features/chat/widgets/workspace_tool_ui_test.dart'
)
PHASE13_SOURCE_FILES=(
  'lib/core/services/skills/skill_import_manifest.dart'
  'lib/core/services/skills/skills_catalog_adapter.dart'
  'lib/core/services/skills/skill_archive.dart'
  'lib/core/services/skills/skills_service.dart'
  'lib/core/services/skills/skill_executor.dart'
  'lib/core/services/skills/skill_execution_security.dart'
  'lib/core/services/runtime_profiles/runtime_profile_models.dart'
  'lib/core/services/runtime_profiles/runtime_profile_service.dart'
  'lib/core/services/packages/package_manager_service.dart'
  'lib/core/services/sandbox/environment_dependencies.dart'
  'lib/core/services/video_engines/video_engine_service.dart'
  'lib/core/services/conversation_tool_permissions.dart'
  'lib/core/services/extensions/skill_execution_tools.dart'
)
ANALYZE_TARGETS=("${PHASE13_TEST_FILES[@]}" "${PHASE13_SOURCE_FILES[@]}")
for source_file in "${ANALYZE_TARGETS[@]}"; do
  [[ -s "$source_file" ]] || fail "Missing extended analysis input: $source_file"
done
DART_ANALYSIS_LOG="$REPORT_DIR/phase13-dart-analysis.txt"
set +e
dart analyze --format machine --no-fatal-warnings "${ANALYZE_TARGETS[@]}" > "$DART_ANALYSIS_LOG" 2>&1
DART_ANALYSIS_STATUS=$?
set -e
if ! bash .github/scripts/check_phase13_dart_analysis.sh \
    "$DART_ANALYSIS_LOG" "$DART_ANALYSIS_STATUS" \
    | tee -a "$REPORT_DIR/phase13-test-preflight.txt"; then
  cat "$DART_ANALYSIS_LOG" | tee -a "$REPORT_DIR/phase13-test-preflight.txt" >&2
  fail 'Extended Dart static analysis found compile/syntax errors or could not complete.'
fi
record "PASS: extended analyzer checked ${#ANALYZE_TARGETS[@]} inputs."

NATIVE_ASSET_SMOKE='test/ci/phase13_native_asset_preflight_test.dart'
[[ -s "$NATIVE_ASSET_SMOKE" ]] || fail 'Dedicated Linux native-asset preflight test is missing.'
record 'Running the optional Linux super_clipboard native-asset smoke test.'
flutter test --no-pub --concurrency=1 --reporter=expanded "$NATIVE_ASSET_SMOKE" \
  || fail 'Extended Linux native-asset smoke test failed.'
record 'PASS: Extended Dart analysis and Linux Native Asset smoke completed.'
mark_preflight_passed
