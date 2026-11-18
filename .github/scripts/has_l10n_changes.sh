#!/usr/bin/env bash
# Exit 0 only when this revision changes localization inputs.
set -euo pipefail
CURRENT_SHA="${CURRENT_SHA:-$(git rev-parse HEAD)}"
BASE_SHA="${PR_BASE_SHA:-${PUSH_BEFORE_SHA:-}}"
if [[ -z "$BASE_SHA" || "$BASE_SHA" == "0000000000000000000000000000000000000000" ]] || \
   ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  BASE_SHA="$(git rev-parse "${CURRENT_SHA}^" 2>/dev/null || true)"
fi
if [[ -z "$BASE_SHA" ]] || ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  echo "No base commit is available; localization validation will run."
  exit 0
fi
if git diff --quiet "$BASE_SHA" "$CURRENT_SHA" -- l10n.yaml 'lib/l10n/*.arb'; then
  exit 1
fi
exit 0
