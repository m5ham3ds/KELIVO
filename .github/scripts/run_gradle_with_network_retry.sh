#!/usr/bin/env bash
# Retry Gradle dependency resolution only for transient repository/network failures.
# Real compilation, configuration and test failures are returned immediately.
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "Usage: $0 <gradle-command> [arguments...]" >&2
  exit 2
fi

max_attempts="${GRADLE_NETWORK_RETRY_ATTEMPTS:-3}"
if [[ ! "$max_attempts" =~ ^[1-5]$ ]]; then
  echo "GRADLE_NETWORK_RETRY_ATTEMPTS must be an integer from 1 to 5." >&2
  exit 2
fi

tmp_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
mkdir -p "$tmp_root"
attempt_log="$(mktemp "$tmp_root/kelivo-gradle-attempt.XXXXXX.log")"
trap 'rm -f "$attempt_log"' EXIT

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  echo "Gradle execution attempt $attempt/$max_attempts"
  set +e
  "$@" 2>&1 | tee "$attempt_log"
  pipeline_status=("${PIPESTATUS[@]}")
  set -e
  gradle_status="${pipeline_status[0]:-1}"
  tee_status="${pipeline_status[1]:-0}"

  if [[ "$gradle_status" -eq 0 && "$tee_status" -eq 0 ]]; then
    echo "Gradle completed successfully on attempt $attempt."
    exit 0
  fi

  if [[ "$gradle_status" -eq 0 ]]; then
    echo "Gradle succeeded, but writing its log failed (tee exit $tee_status)." >&2
    exit "$tee_status"
  fi

  if ! grep -Eiq \
    'Received status code 429|status code 429|Too Many Requests|status code (502|503|504)|HTTP (502|503|504)|Read timed out|Connection reset|UnknownHostException|Temporary failure in name resolution|Connect timed out|Connection timed out|Service Unavailable|Bad Gateway|Gateway Timeout' \
    "$attempt_log"; then
    echo "Gradle failed for a non-transient reason; not retrying (exit $gradle_status)." >&2
    exit "$gradle_status"
  fi

  if [[ "$attempt" -eq "$max_attempts" ]]; then
    echo "Gradle still failed after $max_attempts attempts due to a repository/network error." >&2
    exit "$gradle_status"
  fi

  delay=$((attempt * 10))
  echo "Detected a transient Maven/network failure. Retrying in $delay seconds..." >&2
  sleep "$delay"
done

exit 1
