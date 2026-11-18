#!/usr/bin/env bash
set -euo pipefail

PR_BASE_SHA="${PR_BASE_SHA:-}"
PUSH_BEFORE_SHA="${PUSH_BEFORE_SHA:-}"
CURRENT_SHA="${CURRENT_SHA:-$(git rev-parse HEAD)}"

if ! bash "$(dirname "${BASH_SOURCE[0]}")/has_l10n_changes.sh"; then
  echo "No ARB or l10n configuration changes in this revision; skipping base-commit localization generation."
  exit 0
fi

BASE_SHA=""
if [[ -n "$PR_BASE_SHA" ]]; then
  BASE_SHA="$PR_BASE_SHA"
elif [[ -n "$PUSH_BEFORE_SHA" && "$PUSH_BEFORE_SHA" != "0000000000000000000000000000000000000000" ]]; then
  BASE_SHA="$PUSH_BEFORE_SHA"
else
  BASE_SHA="$(git rev-parse "${CURRENT_SHA}^" 2>/dev/null || true)"
fi

if [[ -z "$BASE_SHA" ]] || ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  echo "No parent/base commit is available (initial commit); untranslated-message comparison is skipped."
  exit 0
fi

BASE_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/kelivo-l10n-base.XXXXXX")"
cleanup() {
  git worktree remove --force "$BASE_DIR" >/dev/null 2>&1 || true
  rm -rf "$BASE_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Creating base worktree at ${BASE_SHA}"
git worktree add --detach "$BASE_DIR" "$BASE_SHA"
(
  cd "$BASE_DIR"
  echo "Resolving base-commit Flutter dependencies"
  flutter pub get
  echo "Generating base-commit localization data"
  flutter gen-l10n
)

BASE_REPORT="$BASE_DIR/untranslated_messages.json"
# The pre-enhancement Phase 2 baseline used this placeholder filename. Read it
# as a compatibility fallback when comparing the first commit after this fix.
if [[ ! -s "$BASE_REPORT" && -s "$BASE_DIR/desiredFileName.txt" ]]; then
  BASE_REPORT="$BASE_DIR/desiredFileName.txt"
fi
HEAD_REPORT="${GITHUB_WORKSPACE:-$(pwd)}/untranslated_messages.json"
python3 "${GITHUB_WORKSPACE:-$(pwd)}/.github/scripts/check_no_new_untranslated.py" \
  "$BASE_REPORT" "$HEAD_REPORT"
