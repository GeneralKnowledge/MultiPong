# Offline AI — Pong

**Version:** 1.0.0  
**Status:** Normative for offline / vs-AI play  
**Constants:** `constants.json` → `ai` object  

This is a **deterministic input adapter**, not a change to simulation rules.  
The AI produces canonical held actions (`P1_UP` / `P1_DOWN` or `P2_UP` / `P2_DOWN`) that are fed into `step()` exactly like a human.

Online multiplayer MUST NOT run this AI on the server unless a future “bot seat” mode is explicitly specified.

---

## 1. Role

| Setting | Value |
| --- | --- |
| Default offline human seat | **1** (left paddle) |
| Default offline AI seat | **2** (right paddle) |
| When AI acts | Modes `PLAYING` and `POINT_SCORED` only |
| Edge actions | AI never emits `CONFIRM`, `PAUSE`, or `RESTART` |

Human still starts the match (`CONFIRM`), pauses, and restarts.

---

## 2. Algorithm (`simple_track`)

Called once per simulation tick **before** `step`, given the current authoritative state and the AI seat (`1` or `2`).

```text
function ai_held(state, seat) -> list of held action names

if state.mode not in {PLAYING, POINT_SCORED}:
    return []

paddle_y = state.player1.y if seat == 1 else state.player2.y
ball = state.ball

approaching =
    (seat == 1 and ball.vx < 0) or
    (seat == 2 and ball.vx > 0)

if ball.active and approaching:
    target_y = ball.y
else:
    # Ball inactive, or moving away → return to vertical centre
    target_y = PLAYFIELD_HEIGHT / 2

delta = target_y - paddle_y

if delta < -AI_DEADZONE:
    return [P{seat}_UP]
if delta > AI_DEADZONE:
    return [P{seat}_DOWN]
return []
```

| Constant | Value | Meaning |
| --- | --- | --- |
| `AI_DEADZONE` | `12` px | No move while within this distance of target |
| `AI_KIND` | `"simple_track"` | Name of this algorithm |

No randomness. No look-ahead prediction beyond current `ball.y`.

---

## 3. Combining with human input (offline)

Each tick:

```text
human_seat_actions  # UP/DOWN from keys, mapped to P1_* (human seat 1)
ai_actions = ai_held(state, ai_seat=2)
held = human P1_*  ∪  ai P2_*
pressed = human edge actions only
step(state, held, pressed)
```

---

## 4. Dual mode (clients)

| Mode | Who runs `step()` | Opponent |
| --- | --- | --- |
| `online` | Server | Remote human |
| `offline` | Local reference sim | Canonical AI (seat 2) |

Clients MUST use the same AI algorithm and deadzone. Do not invent a “smarter” local bot.

---

## 5. Tests

Machine-readable cases live under `tests/AI_*.json` and call `ai_held` then optionally `step`.  
See test runner support for `"ai_seat"` expectations.
