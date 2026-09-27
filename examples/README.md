# Cross-platform multiplayer examples

Minimal clients that speak [specs/pong/PROTOCOL.md](../specs/pong/PROTOCOL.md).  
They are **examples**, not full polished engine ports — enough to prove any stack can join the same room.

## Prerequisites

```bash
cd backend
python3 -m pip install -r requirements.txt
python3 server.py
```

## Clients

| Platform | Path | How to run |
| --- | --- | --- |
| Python (stdio / optional pygame) | [python/](python/) | `python3 examples/python/client.py` |
| JavaScript (browser) — Phaser / RPG Maker path | [javascript/](javascript/) | open `index.html` via a tiny static server |
| Godot (GDScript) | [gdscript/](gdscript/) | paste into a Godot 4 project |
| Unity (C#) | [csharp/](csharp/) | drop script into a Unity scene |
| Love2D (Lua) | [lua/](lua/) | `love examples/lua` |
| Bevy / Rust | [rust/](rust/) | `cargo run` in that folder |
| Unreal | [unreal/](unreal/) | integration notes + Blueprint-friendly message shapes |
| GameMaker | [gamemaker/](gamemaker/) | GML WebSocket sketch |
| RPG Maker MZ/MV | [rpgmaker/](rpgmaker/) | plugin wrapping the JS client |

## Controls (seat-relative)

| Key | Action |
| --- | --- |
| `W` / `↑` | `UP` |
| `S` / `↓` | `DOWN` |
| `Enter` / `Space` | `CONFIRM` |
| `P` / `Esc` | `PAUSE` |
| `R` | `RESTART` |

The server maps your seat to P1 or P2. Two clients in room `demo` auto-start a match.
