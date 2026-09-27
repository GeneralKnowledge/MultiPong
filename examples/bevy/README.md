# Bevy — simple dual-mode Pong

Beginner-friendly Bevy **0.15** example. Simulation is the shared Rust crate `reference/rust` (`pong_sim`). **No Bevy physics.**

| Mode | Flag | Opponent |
| --- | --- | --- |
| Online | (default) | Remote human via server |
| Offline | `--offline` | Canonical AI (seat 2) |

See also [../BEGINNER.md](../BEGINNER.md).

Same behaviour as the [Pygame client](../python/): shared rules, seat 1 human offline, teal “you” highlight, identical controls. Bevy is Y-up so positions are converted only when drawing.

## Quick start (offline)

```bash
cd examples/bevy
cargo run --release -- --offline
```

Press **Enter** to start. You are the left paddle.

On a VM without a GPU you may need:

```bash
export DISPLAY=:1 WGPU_BACKEND=gl
```

## Online

```bash
python3 backend/server.py          # terminal 1
cd examples/bevy
cargo run --release -- --name bevy1
```

| Flag | Default |
| --- | --- |
| `--offline` | off |
| `--url` | `ws://127.0.0.1:8765` |
| `--room` | `demo` |
| `--name` | `bevy` |

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` · `S` / `↓` | Move |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |
| `Ctrl+Q` | Quit |

## Notes for learners

- Game logic is **not** in Bevy systems — it lives in `pong_sim` (or on the server online).
- Ball is drawn as a small square sprite (circle approx.); paddles match spec sizes.
- Headless rules tests: `cd reference/rust && cargo run --release --bin run_tests`
