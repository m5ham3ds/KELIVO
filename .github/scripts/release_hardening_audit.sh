#!/usr/bin/env bash
# Static Android release-hardening checks. This is not a substitute for an
# APK inspection, dependency audit, signing-key check or device test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() {
  echo "RELEASE HARDENING AUDIT FAILED: $*" >&2
  exit 1
}

manifest='android/app/src/main/AndroidManifest.xml'
gradle='android/app/build.gradle.kts'
ignore='.gitignore'
policy='phases/PHASE-12-SECURITY-RESOURCE-MANAGEMENT-RELEASE.md'

[[ -s "$manifest" ]] || fail 'Android manifest is missing'
[[ -s "$gradle" ]] || fail 'Android app Gradle config is missing'
[[ -s "$ignore" ]] || fail '.gitignore is missing'
[[ -s "$policy" ]] || fail 'Phase 12 network/signing exception policy is missing'
grep -Fq 'android:allowBackup="false"' "$manifest" || fail 'Android backup must stay disabled; Kelivo owns its consistent export format'
grep -Fq 'android:fullBackupContent="false"' "$manifest" || fail 'legacy Android full backup must remain disabled'
grep -Fq 'android:usesCleartextTraffic="true"' "$manifest" || fail 'cleartext network compatibility policy changed; review and update Phase 12 before changing it'
grep -Fq 'Cleartext compatibility exception' "$policy" || fail 'global cleartext compatibility exception is not documented'
ndk_filter_block="$(grep -A 5 -E '^[[:space:]]*ndk[[:space:]]*\{' "$gradle" || true)"
grep -Fq 'abiFilters += listOf("arm64-v8a")' <<< "$ndk_filter_block" \
  || fail 'Android app packaging must restrict defaultConfig.ndk.abiFilters to ARM64 only'
if grep -E 'abiFilters.*(armeabi-v7a|x86|x86_64)' "$gradle" >/dev/null; then
  fail 'Android build must not package non-ARM64 ABIs'
fi
grep -Fq 'signingConfigs.getByName("debug")' "$gradle" || fail 'internal CI signing fallback changed; review release signing before updating this audit'

grep -Fq '/android/key.properties' "$ignore" || fail 'android/key.properties is not ignored'
grep -Fq '*.jks' "$ignore" || fail 'JKS signing files are not ignored'
grep -Fq '*.keystore' "$ignore" || fail 'keystore files are not ignored'
for private_file in android/key.properties; do
  [[ ! -e "$private_file" ]] || fail "private signing configuration must not be included in the source archive: $private_file"
done
private_key_file="$(find android -type f \( -iname '*.jks' -o -iname '*.keystore' -o -iname '*.p12' -o -iname '*.pfx' \) -print -quit)"
[[ -z "$private_key_file" ]] || fail "private signing material must not be included in source: $private_key_file"

credential_store='lib/core/services/video_providers/video_provider_credential_store.dart'
engine_service='lib/core/services/video_engines/video_engine_service.dart'
[[ -s "$credential_store" ]] || fail 'secure provider credential store is missing'
grep -Fq 'flutter_secure_storage' "$credential_store" || fail 'provider credentials are not stored in the Android secure-storage plugin'
grep -Fq 'kelivo.video_provider.v1.' "$credential_store" || fail 'provider credential key namespace changed'
grep -Fq 'sensitiveKey' "$engine_service" || fail 'engine settings no longer reject credential-like keys'
permission_policy='lib/core/services/extensions/extension_permission_policy.dart'
skill_service='lib/core/services/extensions/conversational_extension_service.dart'
provider_manifest='lib/core/services/video_providers/video_provider_manifest.dart'
[[ -s "$permission_policy" ]] || fail 'shared extension permission policy is missing'
grep -Fq 'blockedUntilReviewed' "$permission_policy" || fail 'unknown extension permissions are not blocked pending review'
grep -Fq 'ExtensionPermissionPolicy.review' "$skill_service" || fail 'Skills do not expose permission review during install/inspect'
grep -Fq 'permissionsReview' "$engine_service" || fail 'video engines do not expose permission review'
grep -Fq 'permissionsReview' 'lib/core/services/video_providers/video_provider_connector_service.dart' || fail 'video providers do not expose permission review'
grep -Fq "uri.scheme != 'https'" "$provider_manifest" || fail 'video provider API manifests no longer require HTTPS'

resource_monitor='lib/core/services/device_resources/device_resource_monitor.dart'
native_activity='android/app/src/main/kotlin/com/psyche/kelivo/MainActivity.kt'
[[ -s "$resource_monitor" ]] || fail 'Dart device resource monitor is missing'
grep -Fq 'app.device_resources' "$resource_monitor" || fail 'Dart resource monitor channel is missing'
grep -Fq 'app.device_resources' "$native_activity" || fail 'Android resource telemetry channel is not registered'
for measurement in availableMemoryBytes availableStorageBytes thermalStatus processCpuPercentOfOneCore; do
  grep -Fq "\"$measurement\"" "$native_activity" || fail "native resource measurement is missing: $measurement"
done

workflow='.github/workflows/android-build.yml'
[[ -s "$workflow" ]] || fail "workflow missing: $workflow"
grep -Eq '^permissions:[[:space:]]*$' "$workflow" || fail "explicit workflow permissions missing: $workflow"
[[ ! -e .github/workflows/pr-check.yml ]] || fail 'Redundant localization-only workflow must stay removed'

printf 'Release hardening audit passed: Android backup policy, ARM64 target, documented cleartext exception, signing-secret exclusions, secure credential storage, resource telemetry and explicit CI permissions verified.\n'
printf 'Review note: CI Release APKs use the debug key when android/key.properties is absent; this is an installable test artifact, not a public-store signing claim.\n'
