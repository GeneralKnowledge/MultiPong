# Love2D (Lua) — simple dual-mode Pong

| Mode | Flag | Simulation | Opponent |
| --- | --- | --- | --- |
| Offline | `--offline` | Local `pong_sim.lua` | Canonical AI (seat 2) |
| Online | (default) | Authoritative server | Remote human |

Same behaviour as the [Pygame client](../python/): shared rules, seat 1 human offline, teal “you” highlight, identical controls.

Needs **Love 11.x** with LuaSocket (bundled). Vendored `json.lua` + `ws.lua` — no luarocks.

## Quick start (offline)

```bash
love examples/lua -- --offline
```

## Online

```bash
# terminal 1
python3 backend/server.py

# terminal 2 & 3
love examples/lua -- --name love1
love examples/lua -- --name love2
```

| Flag | Default |
| --- | --- |
| `--offline` | off |
| `--url` | `ws://127.0.0.1:8765` |
| `--room` | `demo` |
| `--name` | `love2d` |

From the idle screen (if the server was down): **O** offline, **C** reconnect.

## Faithfulness tests

```bash
love examples/lua -- --test
```

Runs every fixture in `specs/pong/tests/` against the Lua sim (same suite as Python / JS / Godot).
