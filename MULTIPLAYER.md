# Multiplayer

Cross-platform multiplayer for this project uses the **simplest approach that stays correct across engines**:

```text
Tiny authoritative WebSocket server (JSON)
        ↑↓
Any engine client (send seat input, render received GameState)
```

## Why not P2P / lockstep?

| Approach | Verdict |
| --- | --- |
| **P2P / WebRTC** | NAT traversal, signalling, and per-engine support are heavy for a tiny experiment |
| **Lockstep (each client simulates)** | Attractive given our deterministic `step()`, but **cross-language floats** can diverge (Python vs C# vs JS) |
| **Authoritative server** | One sim, one truth; clients are thin. Matches our existing `GameState` schema |

**Decision:** authoritative server + WebSocket + JSON.

Clients do **not** run authoritative physics online. They:

1. Map local keys → seat actions (`UP` / `DOWN` / `CONFIRM` / …)
2. Send those actions each frame (or on change)
3. Render the `GameState` the server broadcasts

Offline / single-device ports still implement local `step()` per the canonical spec. Online play uses the shared backend.

---

## Components

| Path | Role |
| --- | --- |
| [reference/pong/pong_sim/](reference/pong/pong_sim/) | Canonical Python simulation (also used by the server) |
| [backend/](backend/) | Tiny WebSocket server |
| [specs/pong/PROTOCOL.md](specs/pong/PROTOCOL.md) | Wire protocol |
| [examples/](examples/) | Minimal client for each target platform |

---

## Runtime model

```text
┌─────────────┐   join/input    ┌──────────────────────┐
│  Client A   │ ───────────────►│  backend/server.py   │
│ (any engine)│ ◄───────────────│  60 Hz tick loop     │
└─────────────┘   state/room    │  pong_sim.step()     │
┌─────────────┐                 └──────────────────────┘
│  Client B   │ ───────────────►
│ (any engine)│ ◄───────────────
└─────────────┘
```

- One **room** holds at most **two** players.
- Seat 1 = left paddle, seat 2 = right paddle.
- Server merges both seats into one canonical `InputFrame`, steps once per tick, broadcasts state.
- Extra connections to a full room are rejected (or become spectators later — not required now).

---

## Client responsibilities (all platforms)

1. Open WebSocket to `ws://<host>:8765`
2. Send `join`
3. Read `welcome` → remember `player` (1 or 2)
4. Each display frame: send `input` with **seat-relative** held/pressed actions
5. On `state`: draw `state` (canonical coordinates)
6. Ignore running a second online simulation

Seat-relative actions: `UP`, `DOWN`, `CONFIRM`, `PAUSE`, `RESTART`  
Server maps them to `P1_*` / `P2_*`.

---

## Local vs online

| Mode | Who runs `step()` | Who owns scores | Opponent |
| --- | --- | --- | --- |
| Local / tests / offline | Each implementation | Local `GameState` | Human or [canonical AI](specs/pong/AI_SPEC.md) |
| Online multiplayer | **Server only** | Server `GameState` | Remote human |

Engine ports should keep simulation code for offline faithfulness tests; online mode is an **adapter** that swaps “local step” for “network state”.  
Offline AI is a **deterministic input adapter** (`ai_held`) — not a second ruleset. Do not invent smarter bots.

---

## Scope limits

Kept intentionally small:

- 2 players, one room name (default `demo`)
- No accounts, matchmaking service, relay mesh, or encryption beyond optional `wss` in deployment
- No rollback netcode
- JSON text messages only (easy in every language)

---

## Quick start

```bash
# terminal 1
cd backend && python3 -m pip install -r requirements.txt
python3 server.py

# terminal 2 & 3 — any two examples, e.g.
python3 examples/python/client.py
# open examples/javascript/index.html in a browser (or use the static server noted there)
```

See [examples/README.md](examples/README.md) and [backend/README.md](backend/README.md).
