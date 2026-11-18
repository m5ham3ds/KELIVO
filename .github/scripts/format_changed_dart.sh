#!/usr/bin/env bash
# Format only first-party Dart files changed by this revision. The previous
# implementation formatted more than 1,300 source/test files on every build.
set -euo pipefail

REPORT_DIR="${KELIVO_CI_REPORT_DIR:-build-report}"
mkdir -p "$REPORT_DIR"

CURRENT_SHA="${CURRENT_SHA:-$(git rev-parse HEAD)}"
BASE_SHA="${PR_BASE_SHA:-}"
if [[ -z "$BASE_SHA" ]]; then
  BASE_SHA="${PUSH_BEFORE_SHA:-}"
fi
if [[ -z "$BASE_SHA" || "$BASE_SHA" == "0000000000000000000000000000000000000000" ]] || \
   ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  BASE_SHA="$(git rev-parse "${CURRENT_SHA}^" 2>/dev/null || true)"
fi

if [[ -n "$BASE_SHA" ]] && git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  mapfile -t FILES < <(
    git diff --name-only --diff-filter=ACMR "$BASE_SHA" "$CURRENT_SHA" -- '*.dart' \
      | grep -E '^(lib|test|integration_test)/.*\.dart$' \
      | sort -u || true
  )
else
  # A root/initial commit has no meaningful parent diff. Do not turn a missing
  # comparison base into a repository-wide formatter run (which can touch
  # thousands of unrelated Dart files). Subsequent commits are diff-scoped.
  echo "No base commit is available; skipping changed-file formatting instead of scanning the full Dart tree."
  : > "$REPORT_DIR/dart-format-fixes.patch"
  : > "$REPORT_DIR/dart-format-changed-files.txt"
  : > "$REPORT_DIR/dart-format-input-files.txt"
  exit 0
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No changed first-party Dart files need formatting."
  : > "$REPORT_DIR/dart-format-fixes.patch"
  : > "$REPORT_DIR/dart-format-changed-files.txt"
  : > "$REPORT_DIR/dart-format-input-files.txt"
  exit 0
fi

printf 'Formatting %s changed first-party Dart files (not the complete repository test tree).\n' "${#FILES[@]}"
printf '%s\n' "${FILES[@]}" > "$REPORT_DIR/dart-format-input-files.txt"
dart format "${FILES[@]}"
dart format --output=none --set-exit-if-changed "${FILES[@]}"
git diff --binary -- "${FILES[@]}" > "$REPORT_DIR/dart-format-fixes.patch"
git diff --name-only -- "${FILES[@]}" > "$REPORT_DIR/dart-format-changed-files.txt"
git diff --check -- "${FILES[@]}"

FORMATTED_COUNT="$(wc -l < "$REPORT_DIR/dart-format-changed-files.txt" | tr -d ' ')"
printf 'Formatting complete. Formatter-adjusted files: %s.\n' "$FORMATTED_COUNT"
