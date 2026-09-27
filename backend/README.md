# Backend — authoritative Pong server

Tiny WebSocket + JSON server. Runs the canonical Python simulation at 60 Hz and broadcasts `GameState` to up to two clients per room.

## Why this shape

See [../MULTIPLAYER.md](../MULTIPLAYER.md). One server process is far simpler than P2P and avoids cross-engine lockstep float drift.

## Run

```bash
cd backend
python3 -m pip install -r requirements.txt
python3 server.py
# optional: python3 server.py --host 127.0.0.1 --port 8765
```

Connect clients to `ws://127.0.0.1:8765` (or your machine’s LAN IP for phones / other PCs).

## Smoke test (server + two clients)

From the repo root:

```bash
./tools/smoke_online.sh
```

Starts `server.py`, runs [smoke_test.py](smoke_test.py) (two thin WebSocket clients), then tears the server down.

## Behaviour

| Topic | Behaviour |
| --- | --- |
| Protocol | [../specs/pong/PROTOCOL.md](../specs/pong/PROTOCOL.md) |
| Simulation | [../reference/pong/pong_sim/](../reference/pong/pong_sim/) |
| Room size | 2 players |
| Auto-start | When the 2nd player joins and mode is `MENU`, server injects `CONFIRM` |
| Disconnect | Seat cleared; room state reset to `MENU` |

## Not included

TLS/`wss`, accounts, matchmaking, more than 2 players, spectator mode, encryption beyond what your reverse proxy provides.
