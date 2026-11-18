#!/usr/bin/env bash
# Static checks for Phase 13I Android background task lifecycle hardening.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13I PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  android/app/src/main/kotlin/com/psyche/kelivo/background/GenerationForegroundService.kt \
  android/app/src/main/kotlin/com/psyche/kelivo/background/BackgroundRuntime.kt \
  android/app/src/main/AndroidManifest.xml \
  android/app/src/test/kotlin/com/psyche/kelivo/background/BackgroundRuntimeTest.kt \
  lib/core/models/mobile_background_settings.dart \
  lib/core/providers/settings_provider.dart \
  lib/core/services/mobile_background.dart \
  test/settings_provider_mobile_background_test.dart \
  test/core/services/mobile_background_test.dart \
  .github/scripts/run_phase13i_tests.sh \
  .github/scripts/test_phase13i_ci.sh; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13I component: $file"
done

python3 - <<'PY_PHASE13I'
from pathlib import Path
service = Path('android/app/src/main/kotlin/com/psyche/kelivo/background/GenerationForegroundService.kt').read_text(encoding='utf-8')
runtime = Path('android/app/src/main/kotlin/com/psyche/kelivo/background/BackgroundRuntime.kt').read_text(encoding='utf-8')
settings = Path('lib/core/models/mobile_background_settings.dart').read_text(encoding='utf-8')
provider = Path('lib/core/providers/settings_provider.dart').read_text(encoding='utf-8')
native_tests = Path('android/app/src/test/kotlin/com/psyche/kelivo/background/BackgroundRuntimeTest.kt').read_text(encoding='utf-8')
settings_tests = Path('test/settings_provider_mobile_background_test.dart').read_text(encoding='utf-8')
manifest = Path('android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
checks = [
    ('Android background execution defaults enabled', 'this.androidEnabled = true' in settings),
    ('existing install gets a one-time reliability migration', 'mobile_background_service_reliability_migrated_v3' in provider),
    ('migration turns on execution and completion notifications without resetting custom options', 'androidEnabled: true' in provider and 'notificationsEnabled: true' in provider and 'overlayEnabled' in settings_tests),
    ('background service returns START_STICKY for active operation starts', 'else START_STICKY' in service),
    ('explicit stop action remains non-sticky', 'if (intent?.action == STOP) START_NOT_STICKY' in service),
    ('unexpected service teardown does not cancel active Dart work', 'serviceDestroyedUnexpectedly(this)' in service and 'runtime.stopTasks("foreground_service_stopped")' not in service),
    ('unexpected teardown preserves service-active marker while tasks remain', 'putBoolean("service_was_active", true)' in runtime and 'fun serviceDestroyedUnexpectedly' in runtime),
    ('service owns a partial wake lock while tasks run', 'PARTIAL_WAKE_LOCK' in service),
    ('service is not tied to the Activity task', 'android:stopWithTask="false"' in manifest),
    ('Robolectric regression covers service recreation without cancelling tasks', 'unexpectedServiceDestructionKeepsTheGenerationAndStickyRestartReattaches' in native_tests and 'Service.START_STICKY' in native_tests and 'serviceRestartPending' in native_tests),
    ('Recents removal regression verifies active tasks are not cancelled', 'removingTheActivityKeepsTasksAndWakeLockUntilLastCompletion' in native_tests and 'service.onTaskRemoved(Intent())' in native_tests),
    ('Flutter lifecycle regression keeps active generation after Android Activity leaves', 'leaving the Android activity does not cancel active generation work' in Path('test/core/services/mobile_background_test.dart').read_text(encoding='utf-8')),
    ('settings migration regression keeps overlay customization and enables core runtime', 'existing background customizations are preserved while core execution is migrated on' in settings_tests),
    ('explicit user opt-out remains persistent after migration', 'legacy false defaults migrate once to background execution and notifications' in settings_tests),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

# The generation service must stay in the main app process so the Application-
# owned FlutterEngine/Dart isolate keeps the actual streaming/tool operation alive.
if 'android:process=' in manifest[manifest.find('android:name=".background.GenerationForegroundService"')-400:manifest.find('android:name=".background.GenerationForegroundService"')+500]:
    raise SystemExit('FAIL: generation service was moved to an isolated process')
print('PASS: generation service shares the Application FlutterEngine process')
PY_PHASE13I

bash -n .github/scripts/run_phase13i_tests.sh
bash -n .github/scripts/test_phase13i_ci.sh
echo 'Phase 13I static preflight passed.'
