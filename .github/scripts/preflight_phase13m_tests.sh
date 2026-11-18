#!/usr/bin/env bash
# Static preflight for Phase 13M. No packages are installed and no Skill code is run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail() { echo "Phase 13M PREFLIGHT FAILED: $*" >&2; exit 1; }

for file in \
  lib/core/services/runtime_profiles/runtime_profile_models.dart \
  lib/core/services/runtime_profiles/runtime_profile_service.dart \
  lib/core/services/runtime_profiles/runtime_profile_tools.dart \
  lib/core/services/packages/package_manager_adapters.dart \
  lib/core/services/packages/package_manager_service.dart \
  lib/core/services/packages/package_manager_tools.dart \
  lib/core/services/packages/dependency_resolver.dart \
  lib/features/home/services/tool_handler_service.dart \
  test/core/services/runtime_profiles/runtime_profile_models_test.dart \
  test/core/services/runtime_profiles/runtime_profile_service_test.dart \
  test/core/services/runtime_profiles/runtime_profile_tools_test.dart \
  test/core/services/packages/dependency_resolver_test.dart \
  test/core/services/packages/package_manager_adapters_test.dart \
  test/core/services/packages/package_manager_service_test.dart \
  .github/scripts/run_phase13m_tests.sh \
  .github/scripts/test_phase13m_ci.sh \
  phases/PHASE-13M-DEPENDENCY-RESOLVER-AND-ENVIRONMENT-ISOLATION-AR.md; do
  [[ -s "$file" ]] || fail "Missing or empty Phase 13M component: $file"
done

python3 - <<'PY_PHASE13M'
from pathlib import Path
service = Path('lib/core/services/runtime_profiles/runtime_profile_service.dart').read_text(encoding='utf-8')
models = Path('lib/core/services/runtime_profiles/runtime_profile_models.dart').read_text(encoding='utf-8')
tools = Path('lib/core/services/runtime_profiles/runtime_profile_tools.dart').read_text(encoding='utf-8')
handler = Path('lib/features/home/services/tool_handler_service.dart').read_text(encoding='utf-8')
manager_adapters = Path('lib/core/services/packages/package_manager_adapters.dart').read_text(encoding='utf-8')
manager_service = Path('lib/core/services/packages/package_manager_service.dart').read_text(encoding='utf-8')
resolver = Path('lib/core/services/packages/dependency_resolver.dart').read_text(encoding='utf-8')
resolver_test = Path('test/core/services/packages/dependency_resolver_test.dart').read_text(encoding='utf-8')
profile_test = Path('test/core/services/runtime_profiles/runtime_profile_service_test.dart').read_text(encoding='utf-8')
runner = Path('.github/scripts/run_phase13m_tests.sh').read_text(encoding='utf-8')
report = Path('phases/PHASE-13M-DEPENDENCY-RESOLVER-AND-ENVIRONMENT-ISOLATION-AR.md').read_text(encoding='utf-8')
checks = [
    ('Runtime Profile snapshot metadata stores digest, size, ownership and ecosystems', all(k in models for k in ['sha256', 'sizeBytes', 'ownerId', 'ecosystems'])),
    ('Snapshot archives are bounded by per-snapshot and per-profile storage limits', all(k in service for k in ['maxSnapshotsPerProfile', 'maxSnapshotBytes', 'maxTotalSnapshotBytesPerProfile'])),
    ('Snapshots exclude the shared apt/apk RootFS and archive only profile roots/lockfiles', 'shared apt/apk' in service and "'python'" in service and "'node'" in service),
    ('Snapshot restore verifies SHA-256, archive size, member paths and owning profile', all(k in service for k in ['runtime_profile_snapshot_digest_mismatch', 'runtime_profile_snapshot_size_mismatch', 'runtime_profile_snapshot_contains_unsafe_path', 'runtime_profile_snapshot_path_mismatch'])),
    ('Snapshot lifecycle is exposed through approval-gated tool actions', all(k in tools for k in ['snapshot', 'snapshots', 'restore_snapshot', 'delete_snapshot']) and all(k in handler for k in ['profiles.createSnapshot', 'profiles.restoreSnapshot', 'profiles.deleteSnapshot'])),
    ('Profile package mutations checkpoint dependencies and attempt snapshot rollback', 'createSnapshot' in manager_service and 'restoreSnapshot' in manager_service and 'environmentSnapshotRestored' in manager_service),
    ('Package manager integrations are registered through an app-owned adapter registry', all(k in manager_adapters for k in ['class PackageManagerAdapterRegistry', 'void register(', 'createRegistry()'])),
    ('Dependency conflict resolution separates package roots and preserves source evidence', all(k in resolver for k in ['isolationKey', 'sourcePath', 'sourceLine', 'incompatible_exact_versions', 'version_ranges_require_native_resolver'])),
    ('Tests cover profile isolation, exact-version conflicts, range uncertainty and real snapshot restore', all(k in resolver_test for k in ['isolated Runtime Profiles', 'exact version conflicts', 'version ranges']) and 'creates, verifies, restores and rejects corrupted profile dependency snapshots' in profile_test),
    ('CI runner includes the focused Phase 13M suites', all(k in runner for k in ['dependency_resolver_test.dart', 'package_manager_adapters_test.dart', 'runtime_profile_models_test.dart', 'runtime_profile_tools_test.dart', 'runtime_profile_service_test.dart', 'package_manager_service_test.dart'])),
    ('Universal skill compatibility is defined without hard-coded bundled Skill names', 'المهارات الست' in report and 'Imported' in report and 'MCP Server' in report),
]
for label, ok in checks:
    if not ok:
        raise SystemExit(f'FAIL: {label}')
    print(f'PASS: {label}')

# Phase 13M core services must remain independent of the six sample Skill IDs.
for filename in [
    'lib/core/services/packages/dependency_resolver.dart',
    'lib/core/services/packages/package_manager_adapters.dart',
    'lib/core/services/runtime_profiles/runtime_profile_service.dart',
]:
    content = Path(filename).read_text(encoding='utf-8').lower()
    for sample_id in ['ig-profile', 'ig-reel', 'ig-viral', 'animation-director', 'arabian-motion-video-director', 'character-visual-director']:
        if sample_id in content:
            raise SystemExit(f'FAIL: {filename} is hard-coded to sample Skill {sample_id}')
print('PASS: dependency and Runtime Profile services do not depend on sample Skill IDs')
PY_PHASE13M

bash -n .github/scripts/run_phase13m_tests.sh
bash -n .github/scripts/preflight_phase13m_tests.sh

echo 'Phase 13M static preflight passed.'
