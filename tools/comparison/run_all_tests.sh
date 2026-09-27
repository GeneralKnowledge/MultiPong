#!/usr/bin/env bash
# Run canonical Pong tests across reference sims (+ Godot when available).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "=== Python ==="
python3 reference/pong/run_tests.py
echo
echo "=== JavaScript ==="
node reference/js/run_tests.mjs
echo
echo "=== Rust ==="
(cd reference/rust && cargo run --quiet --release --bin run_tests)
echo

GODOT_BIN=""
if command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="godot4"
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
fi

if [[ -n "$GODOT_BIN" ]]; then
  echo "=== Godot ($GODOT_BIN) ==="
  "$GODOT_BIN" --headless --path examples/godot -s scripts/run_tests.gd
  echo
else
  echo "=== Godot ==="
  echo "SKIP (godot4/godot not on PATH)"
  echo
fi

echo "All language runners finished."
