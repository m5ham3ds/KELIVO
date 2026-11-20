#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

run_dart_package() {
  local package="$1"
  printf '\n===== Dart package: %s =====\n' "$package"
  (
    cd "$ROOT/dependencies/$package"
    dart pub get
    dart test --reporter expanded
  )
}

run_flutter_package() {
  local package="$1"
  printf '\n===== Flutter package: %s =====\n' "$package"
  (
    cd "$ROOT/dependencies/$package"
    flutter pub get
    if [[ "$package" == "terminal_view" ]]; then
      # Keep checked-in generated mocks compatible with the resolved Mockito.
      dart run build_runner build --delete-conflicting-outputs
    fi
    flutter test --reporter expanded
  )
}

# These packages own independent test graphs. They are not executed by
# "flutter test" at the KELIVO root because Flutter only discovers root tests.
run_dart_package "mcp_client"
run_dart_package "downsize"
run_flutter_package "flutter_math_fork"
run_flutter_package "markstream"
run_flutter_package "terminal_view"

printf '\nAll vendored local package test suites passed.\n'
