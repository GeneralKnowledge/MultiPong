# Comparison tooling

## Now: cross-language canonical tests

```bash
./tools/comparison/run_all_tests.sh
```

Runs the same `specs/pong/tests/` pack against:

- Python (`reference/pong`)
- JavaScript (`reference/js`)
- Rust (`reference/rust`)

Each runner must print `14/14 passed` (or current total).

## Later

Aggregate per-engine report JSON and replay trace diffs — see [TESTING.md](../../TESTING.md) §6.
