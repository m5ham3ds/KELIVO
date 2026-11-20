#!/usr/bin/env bash
# Static checks for Phase 13G background execution, approval actions and progress notifications.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13G PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/models/mobile_background_settings.dart \
  lib/core/services/mobile_background.dart \
  lib/core/providers/settings_provider.dart \
  lib/features/home/services/tool_approval_service.dart \
  lib/features/home/services/tool_handler_service.dart \
  lib/core/services/video_engines/video_engine_service.dart \
  lib/core/services/video_providers/video_provider_connector_service.dart \
  lib/core/services/video_production/video_production_service.dart \
  lib/core/services/video_hybrid/video_hybrid_workflow_service.dart \
  android/app/src/main/kotlin/com/psyche/kelivo/background/BackgroundRuntime.kt \
  android/app/src/main/kotlin/com/psyche/kelivo/background/GenerationForegroundService.kt \
  android/app/src/main/kotlin/com/psyche/kelivo/background/ToolApprovalActionReceiver.kt \
  android/app/src/main/AndroidManifest.xml \
  android/app/src/test/kotlin/com/psyche/kelivo/background/BackgroundRuntimeTest.kt \
  test/core/services/mobile_background_test.dart \
  test/features/home/services/tool_approval_service_test.dart \
  test/settings_provider_mobile_background_test.dart \
  test/features/settings/pages/mobile_background_settings_page_test.dart \
  .github/scripts/run_phase13g_tests.sh; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13G component: $file"
done

python3 - <<'PY_PHASE13G'
from pathlib import Path
import re

background = Path('lib/core/services/mobile_background.dart').read_text(encoding='utf-8')
settings = Path('lib/core/models/mobile_background_settings.dart').read_text(encoding='utf-8')
settings_provider = Path('lib/core/providers/settings_provider.dart').read_text(encoding='utf-8')
approval = Path('lib/features/home/services/tool_approval_service.dart').read_text(encoding='utf-8')
native = Path('android/app/src/main/kotlin/com/psyche/kelivo/background/BackgroundRuntime.kt').read_text(encoding='utf-8')
service = Path('android/app/src/main/kotlin/com/psyche/kelivo/background/GenerationForegroundService.kt').read_text(encoding='utf-8')
receiver = Path('android/app/src/main/kotlin/com/psyche/kelivo/background/ToolApprovalActionReceiver.kt').read_text(encoding='utf-8')
manifest = Path('android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
handler = Path('lib/features/home/services/tool_handler_service.dart').read_text(encoding='utf-8')
engine = Path('lib/core/services/video_engines/video_engine_service.dart').read_text(encoding='utf-8')
provider = Path('lib/core/services/video_providers/video_provider_connector_service.dart').read_text(encoding='utf-8')
hybrid = Path('lib/core/services/video_hybrid/video_hybrid_workflow_service.dart').read_text(encoding='utf-8')

checks = [
    ('Android background execution defaults on', 'this.androidEnabled = true' in settings),
    ('completion notifications default on', 'this.notificationsEnabled = true' in settings),
    ('background execution upgrades old profiles with a one-time v2 defaults migration and v3 reliability migration', 'mobile_background_execution_defaults_migrated_v2' in settings_provider and 'mobile_background_service_reliability_migrated_v3' in settings_provider),
    ('background task snapshots include actual progress and label', "'progressPercent'" in background and "'progressLabel'" in background),
    ('progress is clamped to a valid fraction', 'progress.clamp(0.0, 1.0).toDouble()' in background),
    ('tool approvals create a minimal safe notification payload', all(token in approval for token in ("'toolCallId'", "'conversationId'", "'toolName'", 'approvalAction')) and 'api_key' not in approval),
    ('tool approval notification has approve and deny native actions', 'Approve' in native and 'Deny' in native and 'APPROVAL_ALLOWED_EXTRA' in native),
    ('approval receiver sends the original decision to the active Flutter engine', 'approvalChannel?.invokeMethod' in native and 'receiveApprovalAction(intent)' in receiver),
    ('approval receiver is registered as private', '.background.ToolApprovalActionReceiver' in manifest and 'android:exported="false"' in manifest),
    ('foreground service remains independent of the Activity task', 'android:stopWithTask="false"' in manifest and 'if (!shouldRunService()) stopTasks("background_execution_disabled")' in native),
    ('foreground service holds wake lock until task completion', 'PARTIAL_WAKE_LOCK' in service and 'stopGenerationService()' in service),
    ('foreground service reports a timeout interruption', 'override fun onTimeout' in service and 'foreground_service_timeout' in service),
    ('Android status notification has a determinate or indeterminate progress bar', '.setProgress(100, task?.progressPercent ?: 0, task?.progressPercent == null)' in native),
    ('video engine forwards real reported progress markers', 'KELIVO_PROGRESS' in engine and 'onProgress(bounded)' in engine),
    ('provider download forwards byte-count progress when a length exists', 'Stream<List<int>> trackedBytes() async*' in provider and 'declaredLength' in provider and 'onProgress?.call' in provider),
    ('provider polling and downloading connect to notification progress', "!const {'poll', 'download'}.contains(action)" in handler and "'Downloading generated video'" in handler),
    ('hybrid scenes pass through engine and provider progress', 'onProgress: onProgress' in hybrid and 'value) => onProgress(value.round())' in hybrid),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

# Native notification payload must never include tool arguments, workspace ids,
# filesystem paths or credentials.
show_start = approval.index("invokeMethod<bool>('show'")
show_end = approval.index('return completer.future;', show_start)
show_body = approval[show_start:show_end]
for forbidden in ("'arguments':", "'requestedPath':", "'workspaceId':", "'api_key':", "'password':"):
    if forbidden in show_body:
        raise SystemExit(f'FAIL: approval notification exposes sensitive field {forbidden}')
print('PASS: approval notification payload is limited to tool/call/conversation identifiers')

# Notifications use the same in-progress task; do not create a second task engine.
if 'MobileBackgroundCoordinator.instance.updateForConversation' not in handler:
    raise SystemExit('FAIL: video/skill tools do not update the existing conversation task')
print('PASS: tools report progress into the existing chat generation task')
PY_PHASE13G

# The Android-native receiver/service behavior must run through Robolectric in CI,
# not merely compile as part of the APK build.
python3 - <<'PY_NATIVE_CI'
from pathlib import Path
workflow = Path('.github/workflows/android-build.yml').read_text(encoding='utf-8')
for token in ('id: android_full_unit_tests', ':app:testDebugUnitTest'):
    if token not in workflow:
        raise SystemExit(f'FAIL: Android runtime tests are not wired into CI: {token}')
print('PASS: complete Android JVM/Robolectric suite is scheduled in Android CI')
PY_NATIVE_CI

# Preserve the already accepted historical 13A–13D test decision.
if grep -Eq 'run_phase13[abcd]_(import|executor|workspace|execution)_tests\.sh' .github/workflows/android-build.yml .github/scripts/run_phase13g_tests.sh; then
  fail 'Phase 13G must not rerun historical Phase 13A–13D suites.'
fi
bash -n .github/scripts/run_phase13g_tests.sh

echo 'Phase 13G static preflight passed.'
