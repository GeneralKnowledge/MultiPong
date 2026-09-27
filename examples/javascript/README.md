# JavaScript canvas client

Dual-mode browser client. Presentation matches `specs/pong`. Offline uses the canonical JS sim + `simple_track` AI.

| Mode | How | Who simulates | Opponent |
| --- | --- | --- | --- |
| Offline | **Offline vs AI** button or `?offline=1` | Local `reference/js` sim | Canonical AI (seat 2) |
| Online | **Connect** | Authoritative server | Remote human |

Serve from the **repo root** so the page can import `reference/js/pong_sim.js`.

## Run

```bash
# from repository root
python3 -m http.server 8080
```

Open:

- Offline: http://127.0.0.1:8080/examples/javascript/?offline=1  
- Online P1: http://127.0.0.1:8080/examples/javascript/?name=alice  
- Online P2: http://127.0.0.1:8080/examples/javascript/?name=bob  

For online play, also run `python3 backend/server.py`.

Query params: `name`, `room`, `url`, `autostart=1`, `offline=1`.

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |

Your paddle is outlined in teal. `window.MultiPongClient` exposes `getState` / `getYou` / `getMode` / `startOffline`.
