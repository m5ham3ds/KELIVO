#!/usr/bin/env bash
# Phase 13A import smoke tests are the default CI gate. The complete importer
# regression suites remain available through workflow_dispatch's extended mode.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .github/scripts/phase13_test_gate.sh
phase13_require_ready "13A"

if [[ "${KELIVO_EXTENDED_PHASE13_TESTS:-false}" == "true" ]]; then
  echo "Extended Phase 13A regression mode: running all importer suites."
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    test/core/services/skills/skill_import_manifest_test.dart \
    test/core/services/skills/skill_archive_test.dart \
    test/core/services/skills/skills_catalog_adapter_test.dart \
    test/core/services/skills/skills_service_test.dart
else
  echo "Fast CI mode: running binary/hidden/shared-resource import smoke tests only."
  flutter test --no-pub --concurrency=2 --reporter=expanded \
    --name 'indexes hidden, nested, binary and executable source files without running them|records shared resources as explicit separate references|repository extractor preserves shared files, hidden files and binary assets' \
    test/core/services/skills/skill_import_manifest_test.dart \
    test/core/services/skills/skill_archive_test.dart
fi

phase13_mark_passed "13A"
