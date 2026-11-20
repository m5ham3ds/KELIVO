#!/usr/bin/env bash
# Run the end-to-end Skill lifecycle on a connected Android emulator or device.
# This test can install the PRoot environment when it is absent; allow network
# access and sufficient storage on the selected Android target.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

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

printf 'Phase 13P target device: %s\n' "$DEVICE_ID"
adb -s "$DEVICE_ID" get-state | grep -Fxq device

# integration_test is a dev dependency. Generate the Debug plugin registrant
# for this lane only; the main workflow restores its selected Release/Debug
# registrant in the following prepare_android_plugin_registrant step.
flutter build apk --debug --config-only
for test_file in \
  integration_test/browser_navigation_runtime_test.dart \
  integration_test/browser_workspace_runtime_test.dart \
  integration_test/browser_workspace_app_runtime_test.dart \
  integration_test/workspace/skill_execution_e2e_test.dart; do
  echo "Running Android integration test: $test_file"
  flutter test --no-pub -d "$DEVICE_ID" "$test_file" --reporter expanded
done
