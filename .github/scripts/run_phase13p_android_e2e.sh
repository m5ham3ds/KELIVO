#!/usr/bin/env bash
# Run browser runtime and the end-to-end Skill ZIP-to-output lifecycle on Android.
# Every integration file gets a clean app process/data state. This avoids carrying
# WebView/Chromium renderer state and Flutter engine resources across test APK runs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

APP_ID="com.psyche.kelivo"

if ! command -v adb >/dev/null 2>&1; then
  echo 'adb is required for the Phase 13P Android integration test.' >&2
  exit 2
fi

DEVICE_ID="${ANDROID_SERIAL:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
if [[ -z "$DEVICE_ID" ]]; then
  echo 'No authorized Android emulator/device is connected. Check adb devices.' >&2
  adb devices >&2 || true
  exit 2
fi

adb -s "$DEVICE_ID" get-state | grep -Fxq device
printf 'Phase 13P target device: %s\n' "$DEVICE_ID"
printf 'Target application: %s\n' "$APP_ID"
adb -s "$DEVICE_ID" shell getprop sys.boot_completed

# The published APK remains ARM64-only. This emulator is x86_64, so build
# this temporary Debug test APK with the matching x86_64 PRoot runtime. This
# property is scoped to this script and cannot affect the release APK build.
export ORG_GRADLE_PROJECT_kelivoE2E=true

# Generate the Debug plugin registrant for this lane only. The main workflow
# restores its selected Release registrant before building the production APK.
flutter build apk --debug --config-only

run_integration_test() {
  local test_file="$1"
  local test_status=0
  local clear_output=""

  printf '\n===== Android integration test: %s =====\n' "$test_file"

  # The emulator starts clean for the first file. Before every subsequent file,
  # stop the previous Flutter engine and clear app/WebView storage so no stale
  # renderer, cookie database, or plugin state leaks into the next test process.
  if adb -s "$DEVICE_ID" shell pm path "$APP_ID" >/dev/null 2>&1; then
    adb -s "$DEVICE_ID" shell am force-stop "$APP_ID" || true
    clear_output="$(adb -s "$DEVICE_ID" shell pm clear "$APP_ID" 2>&1 | tr -d '\r')"
    printf 'App data reset: %s\n' "$clear_output"
    if [[ "$clear_output" != "Success" ]]; then
      echo "Could not reset $APP_ID before $test_file" >&2
      adb -s "$DEVICE_ID" shell pm path "$APP_ID" >&2 || true
      return 2
    fi
  else
    echo 'App is not installed yet; the first flutter test invocation will install it.'
  fi

  adb -s "$DEVICE_ID" logcat -c
  set +e
  # Android API 35 emulator DDS startup is flaky during integration_test;\n  # run against the VM service directly to avoid the emulator-side DDS failure.\n  flutter test --no-pub --no-dds -d "$DEVICE_ID" "$test_file" --reporter expanded
  test_status=$?
  set -e

  if (( test_status != 0 )); then
    echo "ANDROID INTEGRATION TEST FAILED: $test_file (exit $test_status)" >&2
    echo '===== Device package/process state =====' >&2
    adb -s "$DEVICE_ID" shell pm path "$APP_ID" >&2 || true
    adb -s "$DEVICE_ID" shell pidof "$APP_ID" >&2 || true
    adb -s "$DEVICE_ID" shell dumpsys meminfo "$APP_ID" >&2 || true
    adb -s "$DEVICE_ID" shell dumpsys activity processes >&2 || true
    echo '===== Android logcat (last 1800 lines) =====' >&2
    adb -s "$DEVICE_ID" logcat -d -b all -v threadtime 2>&1 | tail -n 1800 >&2 || true
    return "$test_status"
  fi

  # Stop the completed test process before the next file is installed/launched.
  adb -s "$DEVICE_ID" shell am force-stop "$APP_ID" || true
  printf 'Android integration test passed: %s\n' "$test_file"
}

# Run the full WebView/app integration first, while the emulator and Chromium
# renderer are fresh. The lighter navigation fixtures follow, then the actual
# PRoot/Skill lifecycle test runs with the same clean-process boundary.
run_integration_test integration_test/browser_workspace_app_runtime_test.dart
run_integration_test integration_test/browser_navigation_runtime_test.dart
run_integration_test integration_test/browser_workspace_runtime_test.dart
run_integration_test integration_test/workspace/skill_execution_e2e_test.dart

printf '\nAll Phase 13P Android integration tests passed.\n'

# Stop the Gradle daemon started by the temporary x86_64 test build so the
# later ARM64 package step cannot inherit any emulator-only daemon state.
unset ORG_GRADLE_PROJECT_kelivoE2E
gradle --stop -p android
