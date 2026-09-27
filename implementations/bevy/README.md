# Pong — Bevy

| Field | Value |
| --- | --- |
| Engine | Bevy |
| Language | Rust |
| Engine version | 0.15 |
| Spec | `specs/pong` v1.1.0 |
| Status | **Dual-mode client in `examples/bevy/`** |

## Install & run

See [examples/bevy/README.md](../../examples/bevy/README.md).

```bash
cd examples/bevy
cargo run --release -- --offline
# or online:
cargo run --release -- --name bevy1
```

## Tests

Canonical headless tests (shared Rust sim):

```bash
cd reference/rust && cargo run --release --bin run_tests
```

## Spec mapping

| Canonical | Bevy |
| --- | --- |
| GameState | `pong_sim::GameState` |
| `step()` / `ai_held()` | `reference/rust` |
| InputFrame | Collected from `ButtonInput<KeyCode>` |
| Render | Sprites + Text2d (adapter converts Y) |

## Coordinate conversion

Canonical Y-down → Bevy Y-up at render only: `(x - 400, 300 - y)`.

## Known differences

- Ball rendered as a square sprite of side `2 * BALL_RADIUS` (approx. circle).
- “Your paddle” highlight is a translucent teal sprite behind the paddle (not a stroke outline).

## Test results

Sim/AI: covered by `reference/rust` (18/18). Client: manual dual-mode checklist.
