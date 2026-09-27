# Cross-platform multiplayer examples

Simple clients that speak [specs/pong/PROTOCOL.md](../specs/pong/PROTOCOL.md).  
**New here?** Start with [BEGINNER.md](BEGINNER.md).

Python / JavaScript / Phaser / Rust / Bevy / Godot are **dual-mode**: online (authoritative server) or offline (local sim + [canonical AI](../specs/pong/AI_SPEC.md)).

## Prerequisites (online)

```bash
cd backend
python3 -m pip install -r requirements.txt
python3 server.py
```

## Clients

| Platform | Path | Offline | Online |
| --- | --- | --- | --- |
| Python (Pygame, polished) | [python/](python/) | `--offline` | `--name alice` |
| JavaScript (canvas, polished) | [javascript/](javascript/) | `?offline=1` (serve from repo root) | `?name=alice` |
| Phaser 3 (polished) | [phaser/](phaser/) | `?offline=1` (serve from repo root) | `?name=phaser1` |
| Rust (macroquad, polished) | [rust/](rust/) | `--offline` | `--name rust1` |
| Bevy 0.15 (polished) | [bevy/](bevy/) | `--offline` | `--name bevy1` |
| Godot 4.7 (polished) | [godot/](godot/) | `-- --offline` | `-- --online --name godot1` |
| Godot (legacy sketch) | [gdscript/](gdscript/) | — | online-only helper script |
| Unity (C#) | [csharp/](csharp/) | — | drop script into a Unity scene |
| Love2D (Lua) | [lua/](lua/) | — | `love examples/lua` |
| Unreal | [unreal/](unreal/) | — | integration notes |
| GameMaker | [gamemaker/](gamemaker/) | — | GML WebSocket sketch |
| RPG Maker MZ/MV | [rpgmaker/](rpgmaker/) | — | plugin wrapping the JS client |

## Controls (seat-relative)

| Key | Action |
| --- | --- |
| `W` / `↑` | `UP` |
| `S` / `↓` | `DOWN` |
| `Enter` / `Space` | `CONFIRM` |
| `P` / `Esc` | `PAUSE` |
| `R` | `RESTART` |

Online: the server maps your seat to P1 or P2; two clients in room `demo` auto-start.  
Offline: you are always seat 1; seat 2 is the shared `simple_track` AI.
