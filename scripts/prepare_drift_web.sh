#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(awk '/^  drift:/{found=1;next} found && /version:/{gsub(/\"/, "", $2); print $2; exit}' "$root/pubspec.lock")"
if [[ -z "$version" ]]; then
  printf 'Could not find the locked drift version in pubspec.lock.\n' >&2
  exit 1
fi

base="https://github.com/simolus3/drift/releases/download/drift-$version"
cache_buster="$(date +%s)"
curl --fail --location --retry 3 --retry-all-errors --silent --show-error "$base/sqlite3.wasm?refresh=$cache_buster" -o "$root/web/sqlite3.wasm"
curl --fail --location --retry 3 --retry-all-errors --silent --show-error "$base/drift_worker.js?refresh=$cache_buster" -o "$root/web/drift_worker.js"
