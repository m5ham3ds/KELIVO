#!/usr/bin/env bash
# Package the ARM64 APK and persist verifiable artifact metadata for CI reports.
set -euo pipefail

BUILD_MODE="${BUILD_MODE:-release}"
case "$BUILD_MODE" in
  release|debug) ;;
  *) echo "Unsupported BUILD_MODE: $BUILD_MODE" >&2; exit 2 ;;
esac

REPORT_DIR="${KELIVO_CI_REPORT_DIR:-build-report}"
VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1 | tr -d '\r')"
if [[ -z "$VERSION" ]]; then
  echo "Could not read application version from pubspec.yaml." >&2
  exit 1
fi

SOURCE="build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
if [[ ! -s "$SOURCE" ]]; then
  echo "Expected APK is missing or empty: $SOURCE" >&2
  exit 1
fi

# Validate the produced archive, not just the Gradle command or artifact name.
# The product and all release/debug APKs from this workflow are ARM64-only.
if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required to validate packaged Android ABIs." >&2
  exit 1
fi
ACTUAL_ABIS="$(unzip -Z1 "$SOURCE" | awk -F/ '$1 == "lib" && NF >= 3 && $3 ~ /\\.so$/ {print $2}' | sort -u)"
EXPECTED_ABIS="arm64-v8a"
if [[ "$ACTUAL_ABIS" != "$EXPECTED_ABIS" ]]; then
  echo "APK ABI validation failed." >&2
  echo "Expected exactly: $EXPECTED_ABIS" >&2
  echo "Found: ${ACTUAL_ABIS:-<none>}" >&2
  echo "Native libraries in other ABIs must be excluded before publishing the APK." >&2
  exit 1
fi
printf 'Verified packaged APK ABI: %s\\n' "$ACTUAL_ABIS"

mkdir -p dist "$REPORT_DIR"
OUTPUT="dist/Kelivo-Android-arm64-v8a-${VERSION}-${BUILD_MODE}.apk"
cp -- "$SOURCE" "$OUTPUT"
APK_SIZE="$(wc -c < "$OUTPUT" | tr -d '[:space:]')"
APK_SHA256="$(sha256sum "$OUTPUT" | awk '{print $1}')"
printf '%s  %s\n' "$APK_SHA256" "$(basename "$OUTPUT")" > "$OUTPUT.sha256"
cat > "$REPORT_DIR/apk_metadata.txt" <<META
APK name: $(basename "$OUTPUT")
APK path: $OUTPUT
APK bytes: $APK_SIZE
APK SHA-256: $APK_SHA256
Build mode: $BUILD_MODE
Target: android-arm64-v8a
META

printf 'APK name: %s\n' "$(basename "$OUTPUT")"
printf 'APK path: %s\n' "$OUTPUT"
printf 'APK bytes: %s\n' "$APK_SIZE"
printf 'APK SHA-256: %s\n' "$APK_SHA256"
