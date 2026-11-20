#!/usr/bin/env bash
# Preserve the full Flutter analyzer report while making only warnings/errors
# blocking in CI. Info-level lint suggestions remain visible for later cleanup.
set -uo pipefail
set -o pipefail

OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT"' EXIT

set +e
flutter analyze --no-pub lib test integration_test 2>&1 | tee "$OUTPUT"
STATUS=${PIPESTATUS[0]}
set -e

if grep -Eq '(^|[[:space:]])(error|warning)[[:space:]]+•' "$OUTPUT"; then
  echo "Flutter analysis gate failed: analyzer errors or warnings were reported." >&2
  exit 1
fi

if [[ "$STATUS" -ne 0 ]] && ! grep -Eq '^[[:space:]]*[0-9]+ issues? found\.' "$OUTPUT"; then
  echo "Flutter analysis command failed without a normal issue summary (exit $STATUS)." >&2
  exit "$STATUS"
fi

echo "Flutter analysis gate passed: no analyzer errors or warnings; info-level lint suggestions are retained in the report."
