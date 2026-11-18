#!/usr/bin/env bash
# Record the outcome of a GitHub-maintained action (checkout/setup-java/setup-flutter).
set -euo pipefail
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <step_id> <step_title> <outcome> [note]" >&2
  exit 2
fi
STEP_ID="$1"
STEP_TITLE="$2"
OUTCOME="$3"
NOTE="${4:-Detailed action output is available in the GitHub Actions run log.}"
REPORT_DIR="${KELIVO_CI_REPORT_DIR:-build-report}"
mkdir -p "$REPORT_DIR/logs"
printf '%s\t%s\t%s\t%s\t%s\n' "$STEP_ID" "$STEP_TITLE" "$OUTCOME" "n/a" "$NOTE" >> "$REPORT_DIR/steps.tsv"
printf '%s\n' "${STEP_TITLE}: ${OUTCOME} — ${NOTE}" | tee -a "$REPORT_DIR/logs/github-actions-steps.log"
