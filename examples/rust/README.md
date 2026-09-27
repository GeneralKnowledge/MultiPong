# Rust (macroquad) multiplayer client

Polished online client. Same WebSocket protocol as Python/JS; renders the authoritative server `GameState` with presentation matching `specs/pong`.

Uses **macroquad** (small 2D layer) — not Bevy — so it stays lightweight alongside the Python/JS clients.

## Requirements

- Rust 1.85+ recommended (tested with 1.98)
- Linux: X11 + OpenGL (usual desktop / cloud agent display)

## Run

```bash
# terminal 1
python3 backend/server.py

# terminal 2
cd examples/rust
cargo run --release -- --name rust1

# pair with Python or JS in the same room, e.g.
python3 examples/python/client.py --name alice --room demo
```

| Flag | Default |
| --- | --- |
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

Your paddle is outlined in teal. Match auto-starts when the second player joins.
