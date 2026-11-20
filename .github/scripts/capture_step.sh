#!/usr/bin/env bash
# Run one CI command, tee its complete output to a per-step log, and retain the real exit code.
set -uo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <step_id> <step_title> -- <command> [args...]" >&2
  exit 2
fi

STEP_ID="$1"
STEP_TITLE="$2"
shift 2
if [[ "$1" != "--" ]]; then
  echo "Expected '--' before command." >&2
  exit 2
fi
shift
if [[ $# -eq 0 ]]; then
  echo "No command supplied." >&2
  exit 2
fi

run_analyze_quality_gate() {
  local output_file="$1"
  shift
  local command_output
  local command_status

  command_output="$(mktemp)"
  set +e
  "$@" > >(tee "$command_output") 2>&1
  command_status=$?
  set -e

  # Flutter analyze exits 1 for info-level lints as well as warnings/errors.
  # Keep the complete report, but CI blocks only on analyzer errors or warnings.
  if grep -Eq '(^|[[:space:]])(error|warning)[[:space:]]+•' "$command_output"; then
    rm -f "$command_output"
    return 1
  fi
  if [[ "$command_status" -ne 0 ]] && ! grep -Eq '^[[:space:]]*[0-9]+ issues? found\.' "$command_output"; then
    rm -f "$command_output"
    return "$command_status"
  fi
  rm -f "$command_output"
  return 0
}

if [[ ! "$STEP_ID" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "Invalid step id: $STEP_ID" >&2
  exit 2
fi

REPORT_DIR="${KELIVO_CI_REPORT_DIR:-build-report}"
LOG_DIR="$REPORT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${STEP_ID}.log"
RESULTS_FILE="$REPORT_DIR/steps.tsv"
START_EPOCH="$(date +%s)"
START_UTC="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

{
  printf '===== %s =====\n' "$STEP_TITLE"
  printf 'Started: %s\n\n' "$START_UTC"
} > "$LOG_FILE"

echo "::group::${STEP_TITLE}"
set +e
"$@" 2>&1 | tee -a "$LOG_FILE"
COMMAND_STATUS=${PIPESTATUS[0]}
set -e
END_EPOCH="$(date +%s)"
END_UTC="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
DURATION=$((END_EPOCH - START_EPOCH))

if [[ "$COMMAND_STATUS" -eq 0 ]]; then
  OUTCOME="success"
else
  OUTCOME="failure"
fi

{
  printf '\nFinished: %s\n' "$END_UTC"
  printf 'Exit code: %s\n' "$COMMAND_STATUS"
} >> "$LOG_FILE"

# The TSV fields are controlled by this script and contain no tabs/newlines.
printf '%s\t%s\t%s\t%s\t%s\n' \
  "$STEP_ID" "$STEP_TITLE" "$OUTCOME" "$DURATION" "logs/${STEP_ID}.log" >> "$RESULTS_FILE"
echo "::endgroup::"

exit "$COMMAND_STATUS"
