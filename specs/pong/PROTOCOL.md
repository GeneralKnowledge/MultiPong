# Pong multiplayer wire protocol

**Transport:** WebSocket, text frames, JSON objects.  
**Default URL:** `ws://127.0.0.1:8765`  
**Version:** `1`

Every message is a single JSON object with a `type` string.

---

## Client → server

### `join`

```json
{ "type": "join", "room": "demo", "name": "player" }
```

| Field | Required | Notes |
| --- | --- | --- |
| `room` | no | Default `"demo"` |
| `name` | no | Display only; default `"player"` |

### `input`

Seat-relative controls for **this** connection’s assigned player:

```json
{ "type": "input", "held": ["UP"], "pressed": [] }
```

| Action | Meaning |
| --- | --- |
| `UP` | Move own paddle toward y = 0 |
| `DOWN` | Move own paddle toward +y |
| `CONFIRM` | Edge: start / continue (server maps to canonical `CONFIRM`) |
| `PAUSE` | Edge: pause toggle |
| `RESTART` | Edge: reset to menu |

Unknown action strings are ignored. Send often (e.g. every frame); server latches the latest `held` set and queues `pressed` until the next sim tick.

### `ping`

```json
{ "type": "ping", "t": 1234567890 }
```

Optional latency check.

---

## Server → client

### `welcome`

```json
{ "type": "welcome", "protocol": 1, "player": 1, "room": "demo", "name": "player" }
```

`player` is `1` or `2`.

### `room`

```json
{ "type": "room", "room": "demo", "players": 1, "seats": { "1": "alice", "2": null } }
```

Broadcast when membership changes.

### `state`

```json
{
  "type": "state",
  "room": "demo",
  "you": 1,
  "state": {
    "mode": "PLAYING",
    "tick": 120,
    "elapsed_time": 2.0,
    "point_pause_remaining": 0,
    "mode_before_pause": null,
    "ball": { "x": 400, "y": 300, "vx": 300, "vy": 0, "active": true },
    "player1": { "y": 300, "score": 0 },
    "player2": { "y": 300, "score": 0 },
    "serving_player": 1,
    "winner": 0
  }
}
```

`state` matches [state.schema.json](state.schema.json). Sent every simulation tick once a room exists (or at a lower rate if configured; default **every tick / 60 Hz**).

### `error`

```json
{ "type": "error", "message": "room full" }
```

### `pong`

```json
{ "type": "pong", "t": 1234567890 }
```

---

## Server gameplay rules (multiplayer layer)

1. Room capacity: **2** seated players.
2. When the second player joins and `mode == MENU`, the server automatically starts a match (synthetic `CONFIRM`) so examples work without coordinated Enter presses. Clients may still send `CONFIRM` / `RESTART`.
3. Each tick, build canonical `InputFrame`:
   - Seat 1 `UP`/`DOWN` → `P1_UP` / `P1_DOWN`
   - Seat 2 `UP`/`DOWN` → `P2_UP` / `P2_DOWN`
   - `CONFIRM` / `PAUSE` / `RESTART` from **either** seat are applied (OR of pressed edges)
4. Disconnect: seat cleared; if `PLAYING`, server may `RESTART` to `MENU` (documented behaviour in server README).

---

## Example session

```text
C1> {"type":"join","room":"demo","name":"a"}
S1< {"type":"welcome","protocol":1,"player":1,"room":"demo","name":"a"}
S*< {"type":"room","room":"demo","players":1,"seats":{"1":"a","2":null}}

C2> {"type":"join","room":"demo","name":"b"}
S2< {"type":"welcome","protocol":1,"player":2,"room":"demo","name":"b"}
S*< {"type":"room",...players:2...}
S*< {"type":"state","you":...,"state":{"mode":"PLAYING",...}}

C1> {"type":"input","held":["UP"],"pressed":[]}
C2> {"type":"input","held":["DOWN"],"pressed":[]}
S*< {"type":"state",...}
```
