# JavaScript canvas multiplayer client

Polished browser client for the authoritative MultiPong server. Presentation matches `specs/pong` (colours, sizes, UI strings).

## Run

```bash
# terminal 1 — game server
python3 backend/server.py

# terminal 2 — static files (needed so the page can load cleanly)
cd examples/javascript
python3 -m http.server 8080
```

Open:

- Player 1: http://127.0.0.1:8080/?name=alice  
- Player 2: http://127.0.0.1:8080/?name=bob  

Or use the Connect form on the page. Query params: `name`, `room`, `url`, `autostart=1`.

Pair with the [Python client](../python/) in the same room for a cross-language match.

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |

Your paddle is outlined in teal. `window.MultiPongClient` exposes `getState` / `getYou` for Phaser reuse.
