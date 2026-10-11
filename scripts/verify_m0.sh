#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p .audit/evidence
log=".audit/evidence/m0-local-builds.log"
: > "$log"
failed=0

run() {
  printf '\n$ %s\n' "$*" | tee -a "$log"
  "$@" >>"$log" 2>&1
  status=$?
  printf 'exit=%s\n' "$status" | tee -a "$log"
  if (( status != 0 )); then failed=1; fi
}

run flutter pub get
run dart format --output=none --set-exit-if-changed .
run flutter analyze
run flutter test
run flutter build web --release
run flutter build apk --release
run flutter build macos --release

if (( failed )); then
  printf '\nM0 local verification failed. See %s\n' "$log" | tee -a "$log"
  exit 1
fi
printf '\nM0 local verification passed. See %s\n' "$log" | tee -a "$log"
