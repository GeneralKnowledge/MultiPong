# Godot 4 dual-mode client

Polished Godot **4.7** client. Simulation is a GDScript port of the canonical rules (`scripts/pong_sim.gd`). **No Godot physics** for paddles/ball.

| Mode | How | Who simulates | Opponent |
| --- | --- | --- | --- |
| Offline | `O` in-game, or `-- --offline` | Local `PongSim` | Canonical `simple_track` AI (seat 2) |
| Online | `C` in-game, or `-- --online` | Authoritative server | Remote human |

Godot 2D is Y-down — same as the spec (no axis flip).

## Requirements

- Godot 4.7+ (`godot4` on PATH recommended)
- Online: `python3 backend/server.py`

Install Godot (Linux example used in Cursor):

```bash
# official build → ~/.local/bin/godot4
curl -sL -o /tmp/godot4.zip \
  https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -o /tmp/godot4.zip -d ~/.local/godot
ln -sfn ~/.local/godot/Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot4
```

## Offline (vs AI)

```bash
godot4 --path examples/godot -- --offline
```

You are seat 1. Enter starts the match.

## Online

```bash
python3 backend/server.py   # other terminal
godot4 --path examples/godot -- --online --name godot1
```

| Flag (after `--`) | Default |
| --- | --- |
| `--offline` / `--online` | idle until O/C |
| `--url` | `ws://127.0.0.1:8765` |
| `--room` | `demo` |
| `--name` | `godot` |

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |
| `O` | Start offline vs AI |
| `C` | Connect online |
| `Ctrl+Q` | Quit |

## Headless smoke tests (GDScript port)

```bash
godot4 --headless --path examples/godot -s scripts/run_tests.gd
```

Full canonical JSON suite remains on the Python/JS/Rust reference runners.

## Spec mapping

| Canonical | Godot |
| --- | --- |
| `GameState` / `step` / `ai_held` | `scripts/pong_sim.gd` (`PongSim`) |
| Online protocol | `WebSocketPeer` + `PROTOCOL.md` |
| Render | `_draw()` on `Node2D` |
| Physics | **Not used** |
