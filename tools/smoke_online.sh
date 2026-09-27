#!/usr/bin/env bash
# Start the authoritative server, run the two-client smoke test, tear down.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HOST="${SMOKE_HOST:-127.0.0.1}"
# Prefer a free ephemeral port so we do not collide with a local server.
PORT="${SMOKE_PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')}"

python3 -m pip install -q -r backend/requirements.txt

python3 backend/server.py --host "$HOST" --port "$PORT" &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

ready=0
for _ in $(seq 1 50); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "FAIL: server exited before becoming ready" >&2
    wait "$SERVER_PID" || true
    exit 1
  fi
  if python3 -c "import socket; s=socket.create_connection(('$HOST', $PORT), 0.2); s.close()" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.1
done

if [[ "$ready" -ne 1 ]]; then
  echo "FAIL: server did not accept connections on $HOST:$PORT" >&2
  exit 1
fi

python3 backend/smoke_test.py --url "ws://$HOST:$PORT"
echo "Online smoke OK (server + 2 clients on $HOST:$PORT)."
