#!/usr/bin/env bash
# Focused Phase 13M dependency isolation and Runtime Profile snapshot tests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/packages/dependency_resolver_test.dart \
  test/core/services/packages/package_manager_adapters_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/runtime_profiles/runtime_profile_models_test.dart \
  test/core/services/runtime_profiles/runtime_profile_tools_test.dart

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart \
  --plain-name 'creates, verifies, restores and rejects corrupted profile dependency snapshots'

flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/services/packages/package_manager_service_test.dart

echo 'Phase 13M dependency resolver, adapter registry and Runtime Profile snapshot tests passed.'
