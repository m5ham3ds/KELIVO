#!/usr/bin/env bash
# Prepare only the Linux runner headers needed when Dart native-asset hooks
# compile super_native_extensions for the flutter-tester host platform.
# These packages are CI host dependencies; they are never bundled into Android.
set -euo pipefail

MODULES=(glib-2.0 gobject-2.0 gio-2.0 gtk+-3.0)

modules_available() {
  command -v pkg-config >/dev/null 2>&1 || return 1
  pkg-config --exists "${MODULES[@]}"
}

if ! modules_available || ! command -v cc >/dev/null 2>&1; then
  echo "GTK/GLib development metadata or a C compiler is missing; installing Linux test-runner build prerequisites."
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    APT=(apt-get)
  else
    APT=(sudo apt-get)
  fi
  "${APT[@]}" update
  "${APT[@]}" install -y --no-install-recommends build-essential pkg-config libgtk-3-dev
fi

if ! modules_available; then
  echo "Required GTK/GLib pkg-config modules remain unavailable after installation." >&2
  for module in "${MODULES[@]}"; do
    pkg-config --modversion "$module" 2>&1 || true
  done
  exit 1
fi

printf 'Linux native-asset test dependencies are available:\n'
for module in "${MODULES[@]}"; do
  printf '  %s %s\n' "$module" "$(pkg-config --modversion "$module")"
done
