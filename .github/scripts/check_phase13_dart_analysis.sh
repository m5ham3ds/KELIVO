#!/usr/bin/env bash
# Fail the Phase 13 preflight on Dart compile/syntax errors or analyzer failure.
# Warnings and infos are retained and counted but are not treated as blockers.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <machine-output-log> <dart-analyze-exit-code>" >&2
  exit 2
fi

ANALYSIS_LOG="$1"
ANALYSIS_STATUS="$2"
[[ -f "$ANALYSIS_LOG" ]] || { echo 'FAIL: Dart analyzer output file is missing.' >&2; exit 1; }

if grep -Eq '^(ERROR|SYNTACTIC_ERROR)\|' "$ANALYSIS_LOG"; then
  echo 'FAIL: Dart analyzer reported at least one compile-time or syntax error.' >&2
  grep -E '^(ERROR|SYNTACTIC_ERROR)\|' "$ANALYSIS_LOG" >&2 || true
  exit 1
fi

if [[ ! "$ANALYSIS_STATUS" =~ ^[0-9]+$ || "$ANALYSIS_STATUS" -ne 0 ]]; then
  echo "FAIL: Dart analyzer did not complete successfully (exit ${ANALYSIS_STATUS})." >&2
  cat "$ANALYSIS_LOG" >&2
  exit 1
fi

warning_count="$(grep -c '^WARNING|' "$ANALYSIS_LOG" || true)"
info_count="$(grep -c '^INFO|' "$ANALYSIS_LOG" || true)"
printf 'PASS: Dart analyzer completed with no fatal errors; warnings=%s infos=%s.\n' \
  "$warning_count" "$info_count"
