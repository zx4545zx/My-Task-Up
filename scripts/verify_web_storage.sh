#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p .audit/evidence
log=.audit/evidence/m2-web-storage.log
: > "$log"
work="$(mktemp -d)"
chrome_pid=''
server_pid=''
cleanup() {
  if [[ -n "$chrome_pid" ]]; then
    kill "$chrome_pid" 2>/dev/null || true
    wait "$chrome_pid" 2>/dev/null || true
  fi
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

run() {
  printf '\n$ %s\n' "$*" | tee -a "$log"
  "$@" >>"$log" 2>&1
}

run flutter build web --release --target=tool/web_database_probe.dart --output-dir="$work/web"
port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
cdp="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work/web" >>"$log" 2>&1 &
server_pid=$!
for _ in $(seq 1 30); do
  if curl --silent --fail "http://127.0.0.1:$port/" >/dev/null; then break; fi
  sleep 0.2
done
kill -0 "$server_pid"

chrome="$(command -v google-chrome || true)"
if [[ -z "$chrome" ]]; then chrome='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'; fi
if [[ ! -x "$chrome" ]]; then
  printf 'Chrome is required for this browser persistence check.\n' | tee -a "$log" >&2
  exit 2
fi
"$chrome" --headless --disable-gpu --no-sandbox --user-data-dir="$work/profile" --remote-debugging-port="$cdp" --remote-allow-origins='*' "http://127.0.0.1:$port/" >>"$log" 2>&1 &
chrome_pid=$!
node - "$cdp" >>"$log" 2>&1 <<'NODE'
const port = process.argv[2];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let response;
for (let attempt = 0; attempt < 50; attempt++) {
  try {
    response = await fetch(`http://127.0.0.1:${port}/json/list`);
    if (response.ok) break;
  } catch {}
  await delay(200);
}
if (!response?.ok) throw new Error('Chrome DevTools did not start.');
const pages = await response.json();
const page = pages.find(target => target.type === 'page');
if (!page) throw new Error('Chrome did not open a page.');
const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});
let id = 0;
async function title() {
  const requestId = ++id;
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Browser probe timed out.')), 5000);
    const listener = event => {
      const message = JSON.parse(event.data);
      if (message.id !== requestId) return;
      clearTimeout(timeout);
      socket.removeEventListener('message', listener);
      resolve(message.result?.result?.value ?? '');
    };
    socket.addEventListener('message', listener);
    socket.send(JSON.stringify({
      id: requestId,
      method: 'Runtime.evaluate',
      params: { expression: 'document.title', returnByValue: true },
    }));
  });
}
for (let attempt = 0; attempt < 60; attempt++) {
  const value = await title();
  if (value.includes('WEB_DATABASE_PERSISTENCE_PASS')) {
    console.log(value);
    socket.close();
    process.exit(0);
  }
  if (value.includes('WEB_DATABASE_PERSISTENCE_FAIL')) {
    throw new Error(value);
  }
  await delay(500);
}
socket.close();
throw new Error('Browser database operation did not finish within 30 seconds.');
NODE
printf '\nBrowser persistence check passed. See %s\n' "$log" | tee -a "$log"
