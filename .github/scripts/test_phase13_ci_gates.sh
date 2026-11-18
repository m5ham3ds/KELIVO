#!/usr/bin/env bash
# Self-test Phase 13 fast/extended gating and A→B→C→D ordering with a fake
# Flutter executable. This never compiles Dart or starts real Phase suites.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export KELIVO_PHASE13_TEST_STATE_FILE="$TMP/state.tsv"
export KELIVO_DART_PACKAGE_CONFIG="$TMP/package_config.json"
export KELIVO_CI_REPORT_DIR="$TMP/report"
export GITHUB_ENV="$TMP/github_env"
export FAKE_FLUTTER_LOG="$TMP/flutter.log"
export FAKE_DART_LOG="$TMP/dart.log"
printf '{"packages":[{"name":"flutter_test"}]}' > "$KELIVO_DART_PACKAGE_CONFIG"

cat > "$TMP/bin/flutter" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo 'Flutter fake stable'
  exit 0
fi
printf '%s\n' "$*" >> "$FAKE_FLUTTER_LOG"
if [[ " $* " == *" --config-only "* ]]; then
  registrant="${KELIVO_ANDROID_PLUGIN_REGISTRANT:?test registrant path is required}"
  mkdir -p "$(dirname "$registrant")"
  {
    echo '// GeneratedPluginRegistrant fake for CI self-test.'
    if [[ "${FAKE_REGISTRANT_HAS_INTEGRATION_TEST_PLUGIN:-false}" == "true" ]]; then
      echo 'flutterEngine.getPlugins().add(new dev.flutter.plugins.integration_test.IntegrationTestPlugin());'
    fi
  } > "$registrant"
fi
exit "${FAKE_FLUTTER_EXIT_CODE:-0}"
FAKE
cat > "$TMP/bin/dart" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo 'Dart SDK fake stable'
  exit 0
fi
printf '%s\n' "$*" >> "$FAKE_DART_LOG"
FAKE
cat > "$TMP/bin/pkg-config" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --modversion)
    if [[ -n "${FAKE_PKG_CONFIG_FAIL_MODULE:-}" && "${2:-}" == "$FAKE_PKG_CONFIG_FAIL_MODULE" ]]; then
      exit 1
    fi
    echo '3.24.38'; exit 0 ;;
  --exists) exit 0 ;;
  --cflags|--libs) echo ''; exit 0 ;;
  *) echo "unexpected pkg-config args: $*" >&2; exit 2 ;;
esac
FAKE
cat > "$TMP/bin/cc" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
echo 'fake C compiler 1.0'
FAKE
chmod +x "$TMP/bin/flutter" "$TMP/bin/dart" "$TMP/bin/pkg-config" "$TMP/bin/cc"
export PATH="$TMP/bin:$PATH"

WORKFLOW_BLOCK="$(sed -n '/id: linux_test_native_deps/,/id: phase13_test_preflight/p' .github/workflows/android-build.yml)"
grep -Fq 'if: success()' <<< "$WORKFLOW_BLOCK" \
  || { echo 'FAIL: Linux native-hook dependencies must run in every successful CI mode.' >&2; exit 1; }
if grep -Fq 'KELIVO_EXTENDED_PHASE13_TESTS' <<< "$WORKFLOW_BLOCK"; then
  echo 'FAIL: Linux GTK/GLib setup was incorrectly made extended-only.' >&2
  exit 1
fi
grep -Fq 'pkg-config --modversion "$module"' .github/scripts/preflight_phase13_tests.sh \
  || { echo 'FAIL: preflight does not verify GTK/GLib modules before Phase 13A.' >&2; exit 1; }

# Fast preflight must verify smoke targets, ordering and the already-prepared
# GTK/GLib host prerequisites without invoking the whole-project analyzer or
# the standalone Native Asset compile/link smoke test.
export KELIVO_EXTENDED_PHASE13_TESTS=false
bash .github/scripts/preflight_phase13_tests.sh >/dev/null
[[ -s "$KELIVO_PHASE13_TEST_STATE_FILE" ]] || { echo 'FAIL: fast preflight did not create its state marker.' >&2; exit 1; }
[[ ! -s "$FAKE_FLUTTER_LOG" ]] || { echo 'FAIL: fast preflight unexpectedly started a Flutter test.' >&2; exit 1; }
[[ ! -s "$FAKE_DART_LOG" ]] || { echo 'FAIL: fast preflight unexpectedly ran Dart analysis.' >&2; exit 1; }

# A missing host module must fail closed before the Phase 13 gate token/marker
# can unlock any Flutter test runner.
export FAKE_PKG_CONFIG_FAIL_MODULE='gtk+-3.0'
if bash .github/scripts/preflight_phase13_tests.sh >/dev/null 2>&1; then
  echo 'FAIL: preflight passed despite missing gtk+-3.0 host metadata.' >&2
  exit 1
fi
[[ ! -e "$KELIVO_PHASE13_TEST_STATE_FILE" ]] \
  || { echo 'FAIL: failed host dependency preflight left a Phase 13 success marker.' >&2; exit 1; }
unset FAKE_PKG_CONFIG_FAIL_MODULE
bash .github/scripts/preflight_phase13_tests.sh >/dev/null
KELIVO_PHASE13_GATE_TOKEN="$(grep '^KELIVO_PHASE13_GATE_TOKEN=' "$GITHUB_ENV" | tail -n1 | cut -d= -f2-)"
export KELIVO_PHASE13_GATE_TOKEN

blocked() {
  local runner="$1"
  if bash "$runner" >/dev/null 2>&1; then
    echo "FAIL: $runner unexpectedly ran without its phase prerequisite." >&2
    exit 1
  fi
}

# A stale marker from another attempt must not unlock the new run.
KELIVO_PHASE13_GATE_TOKEN="stale-run-token" blocked .github/scripts/run_phase13a_import_tests.sh
blocked .github/scripts/run_phase13b_executor_tests.sh
blocked .github/scripts/run_phase13c_workspace_environment_tests.sh
blocked .github/scripts/run_phase13d_execution_security_tests.sh
[[ ! -s "$FAKE_FLUTTER_LOG" ]] || { echo 'FAIL: a phase started before the current run token was used.' >&2; exit 1; }

bash .github/scripts/run_phase13a_import_tests.sh >/dev/null
line_count_before="$(wc -l < "$FAKE_FLUTTER_LOG")"
blocked .github/scripts/run_phase13c_workspace_environment_tests.sh
blocked .github/scripts/run_phase13d_execution_security_tests.sh
[[ "$(wc -l < "$FAKE_FLUTTER_LOG")" == "$line_count_before" ]] \
  || { echo 'FAIL: Phase 13C/13D started before Phase 13B.' >&2; exit 1; }

bash .github/scripts/run_phase13b_executor_tests.sh >/dev/null
line_count_before="$(wc -l < "$FAKE_FLUTTER_LOG")"
blocked .github/scripts/run_phase13d_execution_security_tests.sh
[[ "$(wc -l < "$FAKE_FLUTTER_LOG")" == "$line_count_before" ]] \
  || { echo 'FAIL: Phase 13D started before Phase 13C.' >&2; exit 1; }

bash .github/scripts/run_phase13c_workspace_environment_tests.sh >/dev/null
bash .github/scripts/run_phase13d_execution_security_tests.sh >/dev/null

# Verify the fast lane is targeted and never resolves packages inside tests.
grep -Fq -- '--no-pub' "$FAKE_FLUTTER_LOG" \
  || { echo 'FAIL: a phase test invoked Flutter without --no-pub.' >&2; exit 1; }
grep -Fq -- 'executes only a declared script' "$FAKE_FLUTTER_LOG" \
  || { echo 'FAIL: Phase 13B did not execute its core smoke case.' >&2; exit 1; }
grep -Fq -- '--tags=phase13d' "$FAKE_FLUTTER_LOG" \
  || { echo 'FAIL: Phase 13D did not select its tagged executor policy tests.' >&2; exit 1; }
for runner in \
  .github/scripts/run_phase13a_import_tests.sh \
  .github/scripts/run_phase13b_executor_tests.sh \
  .github/scripts/run_phase13c_workspace_environment_tests.sh \
  .github/scripts/run_phase13d_execution_security_tests.sh; do
  if grep -Eq -- '--plain-name[^[:cntrl:]]*\|' "$runner"; then
    echo "FAIL: $runner uses --plain-name with OR alternatives." >&2
    exit 1
  fi
done
grep -Fq -- '--name indexes hidden, nested, binary and executable source files without running them|records shared resources as explicit separate references|repository extractor preserves shared files, hidden files and binary assets' "$FAKE_FLUTTER_LOG" \
  || { echo 'FAIL: Phase 13A does not use regex-capable --name for its OR selector.' >&2; exit 1; }
[[ "$(wc -l < "$FAKE_FLUTTER_LOG" | tr -d ' ')" == '5' ]] \
  || { echo 'FAIL: fast CI should use only five Flutter test invocations for the 12 smoke cases.' >&2; exit 1; }
for smoke_name in \
  'indexes hidden, nested, binary and executable source files without running them' \
  'records shared resources as explicit separate references' \
  'repository extractor preserves shared files, hidden files and binary assets' \
  'executes only a declared script from a verified snapshot and records output' \
  'rejects execution when the selected interpreter is not in the profile' \
  'media preset installs FFmpeg and verifies both ffmpeg and ffprobe' \
  'project Python operations inherit the workspace default Runtime Profile' \
  'redacts environment-style credential names with prefixes and suffixes' \
  'approval and execution reports disclose the shared writable RootFS' \
  'missing, malformed and legacy grants never imply full access'; do
  grep -Fq -- "$smoke_name" "$FAKE_FLUTTER_LOG" \
    || { echo "FAIL: expected smoke case missing from fast runner commands: $smoke_name" >&2; exit 1; }
done
if grep -Fq 'skills_service_test.dart' "$FAKE_FLUTTER_LOG"; then
  echo 'FAIL: fast CI ran the full SkillsService regression suite.' >&2
  exit 1
fi

# A failed phase must not set a success marker or permit the following phase.
rm -f "$KELIVO_PHASE13_TEST_STATE_FILE"
printf 'token=%s\npreflight=passed\n' "$KELIVO_PHASE13_GATE_TOKEN" > "$KELIVO_PHASE13_TEST_STATE_FILE"
: > "$FAKE_FLUTTER_LOG"
bash .github/scripts/run_phase13a_import_tests.sh >/dev/null
export FAKE_FLUTTER_EXIT_CODE=23
if bash .github/scripts/run_phase13b_executor_tests.sh >/dev/null 2>&1; then
  echo 'FAIL: a failed Phase 13B test runner returned success.' >&2
  exit 1
fi
if grep -Fqx '13B=passed' "$KELIVO_PHASE13_TEST_STATE_FILE"; then
  echo 'FAIL: a failed Phase 13B run recorded a success marker.' >&2
  exit 1
fi
unset FAKE_FLUTTER_EXIT_CODE
blocked .github/scripts/run_phase13c_workspace_environment_tests.sh

# The permission-review test provisions its Runtime Profile before the denied
# Skill execution. It must compare the request count against that setup
# baseline, not assert that the entire adapter request list is empty.
grep -Fq 'final requestsBeforeExecution = runtime.requests.length;' test/core/services/skills/skill_executor_test.dart \
  || { echo 'FAIL: Phase 13D permission-review test is missing its Runtime Profile setup baseline.' >&2; exit 1; }
grep -Fq 'hasLength(requestsBeforeExecution)' test/core/services/skills/skill_executor_test.dart \
  || { echo 'FAIL: Phase 13D permission-review test must assert no additional runtime dispatch.' >&2; exit 1; }
grep -Fq 'An incomplete permission review must not dispatch the Skill to the runtime.' test/core/services/skills/skill_executor_test.dart \
  || { echo 'FAIL: Phase 13D permission-review assertion rationale is missing.' >&2; exit 1; }

# Build-mode configuration must regenerate the Android registrant after Pub
# resolution. Release must exclude dev-only integration_test, while debug may
# retain it because its Gradle variant includes dev plugins.
export KELIVO_ANDROID_PLUGIN_REGISTRANT="$TMP/GeneratedPluginRegistrant.java"
export BUILD_MODE=release
bash .github/scripts/prepare_android_plugin_registrant.sh >/dev/null
if grep -Fq 'dev.flutter.plugins.integration_test.IntegrationTestPlugin' "$KELIVO_ANDROID_PLUGIN_REGISTRANT"; then
  echo 'FAIL: release registrant retained the dev-only integration_test plugin.' >&2
  exit 1
fi
export FAKE_REGISTRANT_HAS_INTEGRATION_TEST_PLUGIN=true
if bash .github/scripts/prepare_android_plugin_registrant.sh >/dev/null 2>&1; then
  echo 'FAIL: release registrant validation accepted a dev-only integration_test reference.' >&2
  exit 1
fi
export BUILD_MODE=debug
bash .github/scripts/prepare_android_plugin_registrant.sh >/dev/null
if ! grep -Fq 'dev.flutter.plugins.integration_test.IntegrationTestPlugin' "$KELIVO_ANDROID_PLUGIN_REGISTRANT"; then
  echo 'FAIL: debug registrant validation unexpectedly removed integration_test.' >&2
  exit 1
fi
unset FAKE_REGISTRANT_HAS_INTEGRATION_TEST_PLUGIN
unset KELIVO_ANDROID_PLUGIN_REGISTRANT

# The release registrant step must be after Android SDK setup and immediately
# before the real --no-pub APK build, with success gating and diagnostics.
workflow_line() {
  grep -n -m1 -E "^[[:space:]]*id: $1$" .github/workflows/android-build.yml | cut -d: -f1
}
sdk_line="$(workflow_line android_sdk_components)"
registrant_line="$(workflow_line prepare_android_plugin_registrant)"
build_line="$(workflow_line build_android_arm64)"
[[ -n "$registrant_line" && "$sdk_line" -lt "$registrant_line" && "$registrant_line" -lt "$build_line" ]] \
  || { echo 'FAIL: build-mode registrant step is missing or out of order.' >&2; exit 1; }
grep -Fq 'flutter build apk "--${BUILD_MODE}" --config-only' .github/scripts/prepare_android_plugin_registrant.sh \
  || { echo 'FAIL: registrant preparation does not invoke Flutter config-only for the selected build mode.' >&2; exit 1; }
grep -Fq 'flutter build apk --no-pub --"$BUILD_MODE" --target-platform android-arm64' .github/workflows/android-build.yml \
  || { echo 'FAIL: final ARM64 build must use --no-pub after the build-mode registrant has been prepared.' >&2; exit 1; }
grep -Fq 'GeneratedPluginRegistrant.java' .github/scripts/prepare_android_plugin_registrant.sh \
  || { echo 'FAIL: registrant preparation does not validate the generated Java file.' >&2; exit 1; }
grep -Fq 'dev.flutter.plugins.integration_test.IntegrationTestPlugin' .github/scripts/prepare_android_plugin_registrant.sh \
  || { echo 'FAIL: release registrant guard for integration_test is missing.' >&2; exit 1; }

# Extended mode must retain the original comprehensive test commands.
grep -Fq 'dart analyze --format machine --no-fatal-warnings' .github/scripts/preflight_phase13_tests.sh \
  || { echo 'FAIL: optional extended mode lost full Dart analysis.' >&2; exit 1; }
grep -Fq 'test/ci/phase13_native_asset_preflight_test.dart' .github/scripts/preflight_phase13_tests.sh \
  || { echo 'FAIL: optional extended mode lost the Linux Native Asset smoke test.' >&2; exit 1; }

printf 'Phase 13 CI orchestration self-test passed: host native-hook prerequisites, regex-safe smoke selectors, fast smoke lane, build-mode Android registrant regeneration/validation, extended-suite retention, A→B→C→D gates, current-run token, --no-pub and failure propagation.\n'
