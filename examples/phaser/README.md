# Phaser 3 dual-mode client

Polished Phaser client for MultiPong. **No Arcade/Matter physics** — positions come from the canonical JS sim (offline) or the authoritative server (online).

| Mode | How | Who simulates | Opponent |
| --- | --- | --- | --- |
| Offline | **Offline vs AI** or `?offline=1` | `reference/js` + `simple_track` AI | AI seat 2 |
| Online | **Connect** | Server | Remote human |

Serve from the **repo root** so imports of `reference/js/pong_sim.js` resolve. Phaser is loaded from jsDelivr CDN.

## Run

```bash
# from repository root
python3 -m http.server 8080
```

Open:

- Offline: http://127.0.0.1:8080/examples/phaser/?offline=1  
- Online: http://127.0.0.1:8080/examples/phaser/?name=phaser1  

For online play, also run `python3 backend/server.py`.

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |

Your paddle gets a teal outline. `window.MultiPongPhaser` exposes `getState` / `getYou` / `getMode`.

## Spec mapping

| Canonical | Phaser |
| --- | --- |
| `GameState` | Plain object from sim / WebSocket |
| `step()` / `aiHeld()` | `reference/js/pong_sim.js` |
| Render | Phaser rectangles/circle/text — presentation only |
| Physics | **Disabled** (not used) |

## Coordinates

Canonical Y-down 800×600. Phaser uses the same (top-left origin, Y-down).
