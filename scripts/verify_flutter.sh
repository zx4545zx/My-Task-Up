#!/usr/bin/env bash
set -uo pipefail

milestone="${1:-}"
if [[ ! "$milestone" =~ ^m(0|[1-9]|10|11)$ ]]; then
  printf 'usage: %s m0|m1|...|m11\n' "$0" >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p .audit/evidence
log=".audit/evidence/${milestone}-local-builds.log"
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
run dart run build_runner build
run scripts/prepare_drift_web.sh
run scripts/verify_web_storage.sh
run dart format --output=none --set-exit-if-changed .
run flutter analyze
run flutter test
run flutter build web --release
run flutter build apk --release
run flutter build macos --release

if (( failed )); then
  printf '\n%s local verification failed. See %s\n' "$milestone" "$log" | tee -a "$log"
  exit 1
fi
printf '\n%s local verification passed. See %s\n' "$milestone" "$log" | tee -a "$log"
