#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p .audit/evidence
work="$(mktemp -d)"
baseline_app_pids=" $(pgrep -x my_task_up | tr '\n' ' ' || true) "
run_pid=''
cleanup() {
  for app_pid in $(pgrep -x my_task_up || true); do
    if [[ "$baseline_app_pids" != *" $app_pid "* ]]; then
      kill "$app_pid" 2>/dev/null || true
    fi
  done
  if [[ -n "$run_pid" ]]; then
    kill "$run_pid" 2>/dev/null || true
    wait "$run_pid" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

flutter run -d macos --release -t tool/m11_responsive_screenshot_probe.dart \
  >"$work/run.log" 2>&1 &
run_pid=$!
for spec in '390 mobile' '900 compact' '1400 desktop'; do
  read -r width name <<<"$spec"
  ready=0
  for _ in $(seq 1 1200); do
    if grep -q "M11_SCREENSHOT_WIDTH=$width" "$work/run.log"; then
      ready=1
      break
    fi
    if ! kill -0 "$run_pid" 2>/dev/null; then
      cat "$work/run.log" >&2
      exit 1
    fi
    sleep 0.25
  done
  if (( ! ready )); then
    cat "$work/run.log" >&2
    printf 'Timed out waiting for the %s-pixel window.\n' "$width" >&2
    exit 1
  fi
  sleep 0.5
  window_id="$(swift -e 'import Cocoa; let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]; let matches = windows.filter { ($0[kCGWindowOwnerName as String] as? String) == "my_task_up" && ($0[kCGWindowName as String] as? String) == "My Task Up" }; let match = matches.max { a, b in let ar = a[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]; let br = b[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]; return (ar["Width"] ?? 0) * (ar["Height"] ?? 0) < (br["Width"] ?? 0) * (br["Height"] ?? 0) }; print(match?[kCGWindowNumber as String] ?? "")')"
  if [[ -z "$window_id" ]]; then
    printf 'Could not find the My Task Up window.\n' >&2
    exit 1
  fi
  screencapture -x -l "$window_id" ".audit/evidence/m11-$name.png"
done
printf 'Captured macOS app screenshots at 390, 900, and 1400 pixels wide.\n' \
  | tee .audit/evidence/m11-screenshots.log
