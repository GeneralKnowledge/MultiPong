# Beginner quick start

Goal: run the **same simple Pong** in a language you know. Rules live in `specs/pong/`; each example is a thin client.

You do **not** need every engine. Pick one.

## 1. Play offline (vs AI) — no server

| If you know… | Run |
| --- | --- |
| Python | `pip install -r examples/python/requirements.txt` then `python3 examples/python/client.py --offline` |
| JavaScript | From repo root: `python3 -m http.server 8080` → open `/examples/javascript/?offline=1` |
| Godot | Install Godot 4.7+, then `godot4 --path examples/godot` (defaults to offline) |
| Rust (simple) | `cd examples/rust && cargo run --release -- --offline` |
| Bevy | `cd examples/bevy && cargo run --release -- --offline` |
| Phaser | From repo root: `python3 -m http.server 8080` → `/examples/phaser/?offline=1` |
| Love2D | Install Love 11.x, then `love examples/lua -- --offline` |

Controls everywhere: **W/S** or arrows, **Enter** to start, **P** pause, **R** restart.  
You are the **left** paddle; the right paddle is the shared `simple_track` AI.

## 2. Play online (two humans)

```bash
python3 backend/server.py
```

Then start **two** clients with different `--name`s (or two browser tabs). Same room (`demo` by default).

Example:

```bash
python3 examples/python/client.py --name alice
godot4 --path examples/godot -- --online --name bob
```

The server is authoritative: clients only send input and draw the state they receive.

## 3. What to read next

1. [specs/pong/GAME_SPEC.md](../specs/pong/GAME_SPEC.md) — rules  
2. [specs/pong/AI_SPEC.md](../specs/pong/AI_SPEC.md) — offline AI  
3. The `README.md` inside the example you chose  

Faithfulness means **same numbers and behaviour**, not the same libraries or scene graphs.
