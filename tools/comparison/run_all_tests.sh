#!/usr/bin/env bash
# Run canonical Pong tests across Python, JS, and Rust reference sims.
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
echo "All language runners finished."
