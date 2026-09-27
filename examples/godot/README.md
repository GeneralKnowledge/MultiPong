# Godot 4 — simple dual-mode Pong

Beginner-friendly Godot **4.7** example. Simulation is GDScript (`scripts/pong_sim.gd`). **No Godot physics.**

| Mode | How | Opponent |
| --- | --- | --- |
| Offline (default) | Editor ▶ Run, or `godot4 --path examples/godot` | Canonical AI (seat 2) |
| Online | `-- --online` or press **C** in-game | Remote human via server |

See also [../BEGINNER.md](../BEGINNER.md).

## Quick start

```bash
# Install Godot 4.7+ and put it on PATH as godot4, then:
godot4 --path examples/godot
```

Press **Enter** to start. You are the left paddle.

Or open `examples/godot` in the Godot editor and press **Play**.

## Online

```bash
python3 backend/server.py          # terminal 1
godot4 --path examples/godot -- --online --name godot1
```

| Flag (after `--`) | Meaning |
| --- | --- |
| `--offline` | Local sim + AI (default) |
| `--online` | Connect to server |
| `--url` | WebSocket URL (default `ws://127.0.0.1:8765`) |
| `--room` / `--name` | Room and display name |

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` · `S` / `↓` | Move |
| `Enter` / `Space` | Confirm / start |
| `P` | Pause |
| `R` | Restart |
| `O` / `C` | Switch offline / online |
| `Ctrl+Q` | Quit |

## Tests (same JSON suite as Python/JS/Rust)

```bash
godot4 --headless --path examples/godot -s scripts/run_tests.gd
```

Loads every file under `specs/pong/tests/`.

## Notes for learners

- Coordinates match the spec (Y-down). No flip needed.
- Online mode does **not** run local physics — it draws server state.
- Older helper script: [../gdscript/](../gdscript/) (prefer this folder).
