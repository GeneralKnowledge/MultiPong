# Rust (macroquad) client

Dual-mode polished client. Same WebSocket protocol as Python/JS online; offline uses `reference/rust` (`pong_sim`) + canonical AI.

Uses **macroquad** (small 2D layer) — not Bevy — so it stays lightweight alongside the Python/JS clients.

| Mode | Flag | Who simulates | Opponent |
| --- | --- | --- | --- |
| Online | (default) | Authoritative server | Remote human |
| Offline | `--offline` | Local `pong_sim` | Canonical `simple_track` AI (seat 2) |

## Requirements

- Rust 1.85+ recommended (tested with 1.98)
- Linux: X11 + OpenGL (usual desktop / cloud agent display)

## Offline (vs AI)

```bash
cd examples/rust
cargo run --release -- --offline
```

You are seat 1. Enter starts the match.

## Online

```bash
# terminal 1
python3 backend/server.py

# terminal 2
cd examples/rust
cargo run --release -- --name rust1

# pair with Python or JS in the same room
python3 examples/python/client.py --name alice --room demo
```

| Flag | Default |
| --- | --- |
| `--offline` | off |
| `--url` | `ws://127.0.0.1:8765` |
| `--room` | `demo` |
| `--name` | `rust` |

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |
| `Ctrl+Q` | Quit |

Your paddle is outlined in teal. Online matches auto-start when the second player joins.
