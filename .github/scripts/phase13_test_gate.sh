#!/usr/bin/env bash
# Shared state gate: the next phase's tests cannot run until the previous
# phase's focused test runner completed successfully in this CI attempt.
set -euo pipefail

phase13_state_file() {
  printf '%s\n' "${KELIVO_PHASE13_TEST_STATE_FILE:-.dart_tool/kelivo_phase13_test_state.tsv}"
}

phase13_has_state() {
  local key="$1"
  local expected="$2"
  local state_file token
  state_file="$(phase13_state_file)"
  token="${KELIVO_PHASE13_GATE_TOKEN:-}"
  [[ -n "$token" && -s "$state_file" ]] || return 1
  grep -Fqx "token=${token}" "$state_file" && grep -Fqx "${key}=${expected}" "$state_file"
}

phase13_require_ready() {
  local phase="$1"
  local required_key
  case "$phase" in
    13A) required_key="preflight" ;;
    13B) required_key="13A" ;;
    13C) required_key="13B" ;;
    13D) required_key="13C" ;;
    *) echo "Unknown Phase 13 stage: $phase" >&2; return 2 ;;
  esac

  if ! phase13_has_state "$required_key" "passed"; then
    echo "Phase $phase tests are blocked: prerequisite '${required_key}=passed' is absent." >&2
    echo "Run the full Phase 13 preflight and earlier phase test gates in order." >&2
    return 78
  fi
}

phase13_mark_passed() {
  local phase="$1"
  local state_file temp_file
  phase13_require_ready "$phase"
  state_file="$(phase13_state_file)"
  case "$phase" in 13A|13B|13C|13D) ;; *) echo "Unknown Phase 13 stage: $phase" >&2; return 2 ;; esac
  if grep -Fq "${phase}=passed" "$state_file" 2>/dev/null; then
    echo "Phase $phase already has a passed marker in this CI attempt." >&2
    return 3
  fi
  temp_file="${state_file}.tmp.$$"
  cat "$state_file" > "$temp_file"
  printf '%s=passed\n' "$phase" >> "$temp_file"
  mv "$temp_file" "$state_file"
  echo "Recorded Phase $phase test gate as passed."
}
