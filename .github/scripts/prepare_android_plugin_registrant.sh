#!/usr/bin/env bash
# Regenerate Flutter's Android plugin registrant for the actual build mode.
# Flutter pub get can emit dev-dependency plugins into GeneratedPluginRegistrant;
# a subsequent --no-pub release build otherwise reuses that unfiltered file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD_MODE="${BUILD_MODE:-release}"
case "$BUILD_MODE" in
  release|debug) ;;
  *)
    echo "Unsupported BUILD_MODE for Android registrant preparation: $BUILD_MODE" >&2
    exit 2
    ;;
esac

REGISTRANT="${KELIVO_ANDROID_PLUGIN_REGISTRANT:-$ROOT/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java}"
REPORT_DIR="${KELIVO_CI_REPORT_DIR:-$ROOT/build-report}"
mkdir -p "$(dirname "$REGISTRANT")" "$REPORT_DIR"

LOCK_BEFORE=""
if [[ -f pubspec.lock ]]; then
  LOCK_BEFORE="$(sha256sum pubspec.lock | awk '{print $1}')"
fi

echo "Regenerating Android plugin metadata in ${BUILD_MODE} mode."
echo "This config-only command intentionally runs with Pub enabled; --no-pub here would skip platform-tool regeneration."
flutter build apk "--${BUILD_MODE}" --config-only

if [[ ! -s "$REGISTRANT" ]]; then
  echo "Flutter config-only did not generate the Android plugin registrant: $REGISTRANT" >&2
  exit 1
fi

if [[ "$BUILD_MODE" == "release" ]] && grep -Fq \
  'dev.flutter.plugins.integration_test.IntegrationTestPlugin' "$REGISTRANT"; then
  echo "Release plugin registrant still contains the dev-only integration_test plugin." >&2
  echo "Refusing to start Gradle: javac would fail because integration_test is excluded from releaseApi." >&2
  exit 1
fi

REGISTRANT_SHA="$(sha256sum "$REGISTRANT" | awk '{print $1}')"
echo "Build-mode plugin registrant generated and validated: $REGISTRANT_SHA"

# The config-only Flutter command performs a Pub verification as required by
# Flutter's platform-tool regeneration path. Preserve any unexpected lockfile
# change for diagnosis; never silently edit the committed lockfile in CI.
if [[ -n "$LOCK_BEFORE" && -f pubspec.lock ]]; then
  LOCK_AFTER="$(sha256sum pubspec.lock | awk '{print $1}')"
  if [[ "$LOCK_BEFORE" != "$LOCK_AFTER" ]]; then
    cp pubspec.lock "$REPORT_DIR/registrant-config-resolved-pubspec.lock"
    if git ls-files --error-unmatch pubspec.lock >/dev/null 2>&1; then
      git diff --binary -- pubspec.lock > "$REPORT_DIR/registrant-config-pubspec-lock-diff.patch" || true
    fi
    echo "::warning::The registrant config-only pass changed pubspec.lock; retained its resolved copy and diff in build-report/."
  else
    echo "pubspec.lock unchanged during build-mode registrant preparation."
  fi
fi

printf 'mode=%s\nregistrant_sha256=%s\nintegration_test_reference=%s\n' \
  "$BUILD_MODE" "$REGISTRANT_SHA" \
  "$(if grep -Fq 'dev.flutter.plugins.integration_test.IntegrationTestPlugin' "$REGISTRANT"; then echo present; else echo absent; fi)" \
  > "$REPORT_DIR/android-plugin-registrant.txt"
