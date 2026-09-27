# Bevy dual-mode client

Polished Bevy 0.15 client. Simulation is the Rust reference (`pong_sim`); Bevy only renders and reads input. **No Bevy physics** for paddles/ball.

| Mode | Flag | Who simulates | Opponent |
| --- | --- | --- | --- |
| Online | (default) | Authoritative server | Remote human |
| Offline | `--offline` | Local `pong_sim` + `simple_track` AI | AI seat 2 |

## Requirements

- Rust 1.85+ (tested with 1.98)
- Linux: X11 + GPU (or software GL via Mesa)
- Runtime libs: `libxkbcommon-x11-0`, Mesa (`libegl1`, `libgl1-mesa-dri`)

On headless / cloud VMs without a discrete GPU:

```bash
export DISPLAY=:1
export WGPU_BACKEND=gl
cargo run --release -- --offline
```

## Offline (vs AI)

```bash
cd examples/bevy
cargo run --release -- --offline
```

You are seat 1. Enter starts the match.

## Online

```bash
python3 backend/server.py   # other terminal
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
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |
| `Ctrl+Q` | Quit |

## Spec mapping

| Canonical | Bevy |
| --- | --- |
| `GameState` / `step` / `ai_held` | `reference/rust` (`pong_sim`) |
| Input | Seat-relative `UP`/`DOWN`/… mapped in offline to `P1_*` |
| Render | Sprites + `Text2d` |
| Physics | **Not used** |

## Coordinates

Canonical space is Y-down, origin top-left. Bevy 2D is Y-up, origin centre. Conversion at the render boundary only:

`bevy_xy = (x - 400, 300 - y)`.

## Tests

Headless canonical tests: `cargo run --release --bin run_tests` in `reference/rust` (shared sim). This client is a presentation/network adapter.
