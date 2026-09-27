# Canonical Game Spec — Pong

**Version:** 1.0.0  
**Status:** Normative for all Pong implementations  
**Tick rate:** 60 Hz (`DT = 1/60` s)  
**Playfield:** 800 × 600 px  

Numbers in [constants.json](constants.json) are authoritative. This document explains rules and behaviour.

---

## 1. Overview

A two-player Pong-like game. Each player controls a vertical paddle. A ball bounces off top/bottom walls and paddles. A point is scored when the ball passes a player's goal line. First to **11** points wins.

### Goals of this game (as a project artifact)

Exercise: game modes, input actions, movement, AABB collision, scoring, fixed timestep, simple UI, audio events, deterministic headless simulation.

### Non-goals (do not implement in the local game rules)

- AI opponent
- Power-ups, spin beyond the specified paddle deflection
- Particle systems affecting gameplay
- Configurable rules mid-match
- Mouse control (unless mapped to the same actions and documented)

Online multiplayer is a **separate layer**: see [PROTOCOL.md](PROTOCOL.md) and [../../MULTIPLAYER.md](../../MULTIPLAYER.md). Online clients do not redefine these rules; the authoritative server runs this simulation.

---

## 2. Playfield

| Property | Value |
| --- | --- |
| Width `PLAYFIELD_WIDTH` | 800 px |
| Height `PLAYFIELD_HEIGHT` | 600 px |
| Origin | Top-left `(0, 0)` |
| +X | Right |
| +Y | Down |
| Background colour | `#0B0E14` |
| Centre line colour | `#2A3344` |
| Centre line dash | 4 px wide, 16 px tall segments, 12 px gap, centred on `x = 400` |

The **playfield** is the simulation space. The window may letterbox; simulation coordinates never leave this space for paddles/ball except when the ball exits for scoring.

---

## 3. Entities

### 3.1 Ball

| Property | Value |
| --- | --- |
| Shape | Circle |
| Radius `BALL_RADIUS` | 8 px |
| Position | Centre `(x, y)` |
| Velocity | `(vx, vy)` in px/s |
| Initial speed `BALL_SPEED_INITIAL` | 300 px/s |
| Maximum speed `BALL_SPEED_MAX` | 600 px/s |
| Speed increase per paddle hit `BALL_SPEED_INCREMENT` | 25 px/s |
| Colour | `#F2F5F8` |

Speed means `speed = hypot(vx, vy) = sqrt(vx*vx + vy*vy)`.

### 3.2 Paddles

| Property | Value |
| --- | --- |
| Width `PADDLE_WIDTH` | 12 px |
| Height `PADDLE_HEIGHT` | 80 px |
| Move speed `PADDLE_SPEED` | 400 px/s |
| Colour | `#E8EEF5` |
| Position | Centre `(x, y)` — **x is fixed**; only **y** changes |

| Paddle | Fixed centre X |
| --- | --- |
| Player 1 (left) | `PADDLE_P1_X = 40` |
| Player 2 (right) | `PADDLE_P2_X = 760` |

### 3.3 Paddle vertical limits

Paddle centre Y is clamped each tick **after** movement:

```text
PADDLE_Y_MIN = PADDLE_HEIGHT / 2                  # 40
PADDLE_Y_MAX = PLAYFIELD_HEIGHT - PADDLE_HEIGHT / 2  # 560

paddle.y = clamp(paddle.y, PADDLE_Y_MIN, PADDLE_Y_MAX)
```

---

## 4. Simulation timestep

```text
TICK_RATE = 60
DT        = 1 / 60
```

Authoritative simulation uses **only** this `DT`. See [ARCHITECTURE.md](../../ARCHITECTURE.md).

### 4.1 Per-tick update order (PLAYING mode)

When `mode == PLAYING`, each tick MUST apply steps in this order:

1. Apply paddle movement from held `P1_*` / `P2_*` actions.
2. Clamp paddle Y.
3. Integrate ball position: `x += vx * DT`, `y += vy * DT` (only if `ball.active`).
4. Resolve top/bottom wall collisions.
5. Resolve paddle collisions (P1 then P2).
6. Check scoring (ball fully past goal lines). This may change `mode` to `POINT_SCORED` or `GAME_OVER`.
7. If `mode` is still `PLAYING` **or** became `POINT_SCORED`, increment `tick` by 1 and set `elapsed_time = tick * DT`.
8. If `mode` became `GAME_OVER`, do **not** increment `tick`.

---

## 5. Input

### 5.1 Canonical actions

| Action | Type | Effect |
| --- | --- | --- |
| `P1_UP` | held | Player 1: `y -= PADDLE_SPEED * DT` |
| `P1_DOWN` | held | Player 1: `y += PADDLE_SPEED * DT` |
| `P2_UP` | held | Player 2: `y -= PADDLE_SPEED * DT` |
| `P2_DOWN` | held | Player 2: `y += PADDLE_SPEED * DT` |
| `CONFIRM` | edge | Mode-dependent (§8) |
| `PAUSE` | edge | Toggle pause when allowed (§8) |
| `RESTART` | edge | Reset to `MENU` (§8) |

If both `UP` and `DOWN` for the same player are held, **net movement is zero** for that player.

### 5.2 Default bindings (presentation only)

| Action | Keyboard (default) |
| --- | --- |
| `P1_UP` | `W` |
| `P1_DOWN` | `S` |
| `P2_UP` | `ArrowUp` |
| `P2_DOWN` | `ArrowDown` |
| `CONFIRM` | `Enter` or `Space` |
| `PAUSE` | `Escape` or `P` |
| `RESTART` | `R` |

Bindings may be remapped; simulation must only see actions.

---

## 6. Collision

Collision is **explicit AABB / circle maths**. Do **not** use engine physics.

### 6.1 Helpers

Paddle AABB (centre-based):

```text
left   = paddle.x - PADDLE_WIDTH / 2
right  = paddle.x + PADDLE_WIDTH / 2
top    = paddle.y - PADDLE_HEIGHT / 2
bottom = paddle.y + PADDLE_HEIGHT / 2
```

Ball overlaps paddle when the closest point on the AABB to the ball centre is within `BALL_RADIUS`:

```text
closest_x = clamp(ball.x, left, right)
closest_y = clamp(ball.y, top, bottom)
dx = ball.x - closest_x
dy = ball.y - closest_y
overlap = (dx*dx + dy*dy) <= (BALL_RADIUS * BALL_RADIUS)
```

### 6.2 Top / bottom walls

After integration, if the ball overlaps a wall, reflect and push out:

```text
# Top
if ball.y - BALL_RADIUS < 0:
    ball.y = BALL_RADIUS
    ball.vy = abs(ball.vy)
    emit wall_hit

# Bottom
if ball.y + BALL_RADIUS > PLAYFIELD_HEIGHT:
    ball.y = PLAYFIELD_HEIGHT - BALL_RADIUS
    ball.vy = -abs(ball.vy)
    emit wall_hit
```

### 6.3 Paddle hits

Process **player 1 paddle first**, then **player 2**.

A paddle hit is only accepted if the ball is moving **toward** that paddle:

- P1: require `ball.vx < 0`
- P2: require `ball.vx > 0`

On accepted overlap:

1. Emit `paddle_hit`.
2. Compute hit offset in `[-1, 1]`:

```text
offset = (ball.y - paddle.y) / (PADDLE_HEIGHT / 2)
offset = clamp(offset, -1, 1)
```

3. Compute new speed:

```text
old_speed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
new_speed = min(old_speed + BALL_SPEED_INCREMENT, BALL_SPEED_MAX)
```

4. Set direction from offset (deflection):

```text
# Max bounce angle from horizontal, degrees
MAX_BOUNCE_ANGLE_DEG = 50

bounce = offset * MAX_BOUNCE_ANGLE_DEG   # degrees
# Convert: direction faces away from paddle
# P1 hit → ball goes right; P2 hit → ball goes left

import math  # conceptual
angle_rad = radians(bounce)
ball.vx = new_speed * cos(angle_rad) * direction  # direction = +1 for P1, -1 for P2
ball.vy = new_speed * sin(angle_rad)
```

Where `sin` / `cos` are standard library maths on radians.  
`direction = +1` after P1 hit, `direction = -1` after P2 hit.

5. Separate ball so it no longer overlaps (prevent tunneling stickiness):

```text
# P1
ball.x = paddle.x + PADDLE_WIDTH / 2 + BALL_RADIUS + 0.01
# P2
ball.x = paddle.x - PADDLE_WIDTH / 2 - BALL_RADIUS - 0.01
```

Use the separation constant `SEPARATION_EPSILON = 0.01` from `constants.json`.

**Note:** At `offset == 0`, `vy` becomes `0` and `|vx|` becomes `new_speed` (travel horizontal).

### 6.4 No paddle–paddle or multi-ball interactions

Not applicable.

---

## 7. Scoring

### 7.1 Goal lines

After wall and paddle resolution:

```text
# Player 2 scores (ball exits left)
if ball.x + BALL_RADIUS < 0:
    player2.score += 1
    emit score
    handle_point_scored(scored_by=2)

# Player 1 scores (ball exits right)
if ball.x - BALL_RADIUS > PLAYFIELD_WIDTH:
    player1.score += 1
    emit score
    handle_point_scored(scored_by=1)
```

Only one scoring event can occur per tick; check left then right (mutually exclusive in practice).

### 7.2 Point scored handling

```text
SCORE_TO_WIN = 11
POINT_PAUSE_DURATION = 1.0   # seconds
```

```text
function handle_point_scored(scored_by):
    if player1.score >= SCORE_TO_WIN or player2.score >= SCORE_TO_WIN:
        mode = GAME_OVER
        winner = 1 if player1.score >= SCORE_TO_WIN else 2
        ball.active = false
        emit game_over
        return

    mode = POINT_SCORED
    point_pause_remaining = POINT_PAUSE_DURATION
    # The player who was scored against serves next.
    # If scored_by == 1 (P1 scored), P2 serves; if scored_by == 2, P1 serves.
    serving_player = 2 if scored_by == 1 else 1
    reset_ball_for_serve(serving_player)
    # paddles retain their Y positions
```

### 7.3 Serve / ball reset

```text
function reset_ball_for_serve(serving_player):
    ball.x = PLAYFIELD_WIDTH / 2      # 400
    ball.y = PLAYFIELD_HEIGHT / 2     # 300
    ball.active = false               # not moving during POINT_SCORED pause
    speed = BALL_SPEED_INITIAL
    # Serve toward the opponent of the server
    # Server is serving_player; ball travels toward the other side.
    if serving_player == 1:
        ball.vx = +speed
        ball.vy = 0
    else:
        ball.vx = -speed
        ball.vy = 0
```

When play resumes from `POINT_SCORED` → `PLAYING`, set `ball.active = true` and keep the velocity set above.

### 7.4 Match start serve

On transition `MENU` → `PLAYING` via `CONFIRM`:

- Scores `0–0`
- Both paddles at `y = PLAYFIELD_HEIGHT / 2` (300)
- `serving_player = 1`
- `reset_ball_for_serve(1)` then immediately `ball.active = true` (no point pause on first serve)
- `mode = PLAYING`
- `tick = 0` (then first step increments to 1 — see §8.6)
- `winner = 0`

---

## 8. Game modes

```text
MENU ──CONFIRM──► PLAYING
PLAYING ──PAUSE──► PAUSED ──PAUSE──► PLAYING
PLAYING ──point──► POINT_SCORED ──timer──► PLAYING
PLAYING / POINT_SCORED ──win──► GAME_OVER
GAME_OVER ──CONFIRM──► MENU
any (except optional lock) ──RESTART──► MENU (full reset)
```

### 8.1 `MENU`

Per-tick order:

1. Apply edge actions only (`CONFIRM`, `RESTART`). Movement ignored.
2. On `CONFIRM`: emit `ui_confirm`, perform match start (§7.4), leave `mode = PLAYING`. Do **not** run PLAYING physics on the same tick.
3. On `RESTART`: reload boot state (§13).
4. `PAUSE` ignored.
5. Do **not** increment `tick`.

Initial boot state is `MENU` with scores 0, paddles centred, ball at centre inactive, `tick = 0`.

### 8.2 `PLAYING`

Per-tick order:

1. Apply edge actions first: `RESTART` → full `MENU` reset (end tick); `PAUSE` → set `mode_before_pause = PLAYING`, `mode = PAUSED` (end tick; do not move entities this tick).
2. Otherwise run §4.1 update order (paddles → ball → walls → paddles collision → score).
3. Scoring may set `POINT_SCORED` or `GAME_OVER` before the tick increment in §4.1.
4. If still in a ticking mode after those transitions, §4.1 already increments `tick`. If `PAUSE`/`RESTART` fired in step 1, skip §4.1 entirely.

### 8.3 `POINT_SCORED`

Per-tick order:

1. Apply edge actions: `RESTART` → full `MENU` reset (stop); `PAUSE` → enter `PAUSED` with `mode_before_pause = POINT_SCORED` (stop further sim this tick).
2. Apply paddle movement from held actions; clamp Y.
3. Do **not** integrate ball.
4. `point_pause_remaining -= DT`.
5. If `point_pause_remaining <= 0`: set `point_pause_remaining = 0`, `mode = PLAYING`, `ball.active = true`.
6. Increment `tick`; update `elapsed_time`.

Paddles **may** move during the pause. Ball stays frozen until step 5 fires.

### 8.4 `PAUSED`

Per-tick order:

1. On `PAUSE`: set `mode = mode_before_pause`, clear `mode_before_pause` to `null`. Do not move entities this tick.
2. On `RESTART`: full `MENU` reset.
3. `CONFIRM` and movement ignored.
4. Do **not** increment `tick`.

### 8.5 `GAME_OVER`

Per-tick order:

1. On `CONFIRM`: emit `ui_confirm`, full `MENU` reset.
2. On `RESTART`: full `MENU` reset (no need for duplicate `ui_confirm`).
3. No movement, no tick increment.

### 8.6 Tick increment rules

| Mode | Increment `tick`? |
| --- | --- |
| `MENU` | No |
| `PLAYING` | Yes, once per step after updates |
| `POINT_SCORED` | Yes (pause timer advances with ticks) |
| `PAUSED` | No |
| `GAME_OVER` | No |

---

## 9. Authoritative state

See [state.schema.json](state.schema.json). Required fields:

| Field | Type | Notes |
| --- | --- | --- |
| `mode` | string enum | |
| `tick` | integer ≥ 0 | |
| `elapsed_time` | number | `tick * DT` when ticking modes; unchanged when not |
| `point_pause_remaining` | number | seconds |
| `mode_before_pause` | string enum or null | |
| `ball.x`, `ball.y` | number | centre |
| `ball.vx`, `ball.vy` | number | |
| `ball.active` | boolean | |
| `player1.y`, `player1.score` | number / int | |
| `player2.y`, `player2.score` | number / int | |
| `serving_player` | 1 or 2 | |
| `winner` | 0, 1, or 2 | |

Derived (optional in dumps): paddle fixed X, AABBs.

Rendering-only (never authoritative): interpolation positions, flash alpha, etc.

---

## 10. Presentation

### 10.1 Always draw (when in play-ish modes)

- Background fill
- Centre dashed line (optional to hide on MENU; SHOULD show on PLAYING / PAUSED / POINT_SCORED / GAME_OVER)
- Both paddles as axis-aligned rectangles
- Ball as filled circle when `ball.active` OR always at position (even inactive during pause between points)
- Scores: Player 1 left-centre-top, Player 2 right-centre-top

### 10.2 UI strings

| Mode | Text |
| --- | --- |
| `MENU` | Title: `PONG` — Subtitle: `Press Enter` |
| `PAUSED` | `PAUSED` |
| `POINT_SCORED` | (scores only; no extra required banner) |
| `GAME_OVER` | `PLAYER 1 WINS` or `PLAYER 2 WINS` — hint: `Press Enter` |

Font: `assets/pong/fonts/PressStart2P-Regular.ttf` if present; otherwise a monospace bitmap font, documented.

Score text colour: `#F2F5F8`.  
UI overlay text colour: `#F2F5F8`.

Score positions (baseline / centre anchors are engine-specific; visual target):

- P1 score centre at approx `(300, 48)`
- P2 score centre at approx `(500, 48)`
- Font size target: 32 px

### 10.3 Menu layout

- Title `PONG` centred near `(400, 220)`, size ~48 px
- Subtitle centred near `(400, 300)`, size ~16 px

Exact font rasterisation may differ slightly; layout intent must match.

---

## 11. Audio events

| Event | When | Asset (basename) |
| --- | --- | --- |
| `paddle_hit` | Paddle collision accepted | `paddle_hit` |
| `wall_hit` | Top/bottom reflect | `wall_hit` |
| `score` | Point scored | `score` |
| `game_over` | Match ends | `game_over` |
| `ui_confirm` | `CONFIRM` accepted on MENU or GAME_OVER | `ui_confirm` |

Formats: prefer WAV in `assets/pong/audio/`. Engines may transcode copies locally but SHOULD start from shared masters.

Until assets exist, short square-wave beeps are acceptable if documented.

---

## 12. Determinism notes

- No RNG in Pong 1.0.0.
- Use `double` precision where available for positions/velocities.
- Trig for paddle bounce: standard `sin`/`cos` on radians of `offset * 50°`.
- Cross-engine compare tolerance (default): `1e-4` absolute for positions and velocities; scores and modes exact.
- Headless: MUST support stepping with injected `InputFrame`s.

### Floating-point angle helper

```text
MAX_BOUNCE_ANGLE_DEG = 50
angle_rad = offset * MAX_BOUNCE_ANGLE_DEG * PI / 180
```

Use `PI` as the platform’s double-precision π.

---

## 13. Initial state (boot / MENU reset)

```json
{
  "mode": "MENU",
  "tick": 0,
  "elapsed_time": 0,
  "point_pause_remaining": 0,
  "mode_before_pause": null,
  "ball": { "x": 400, "y": 300, "vx": 0, "vy": 0, "active": false },
  "player1": { "y": 300, "score": 0 },
  "player2": { "y": 300, "score": 0 },
  "serving_player": 1,
  "winner": 0
}
```

---

## 14. Faithfulness checklist (Pong)

An implementation is faithful when:

1. All constants match `constants.json`.
2. Mode transitions match §8.
3. Collision and scoring match §6–§7.
4. Canonical tests in `tests/` pass within tolerance.
5. Visual layout matches §10 within reasonable raster differences.
6. No engine physics for ball/paddle motion.

---

## 15. File index

| File | Purpose |
| --- | --- |
| [constants.json](constants.json) | Numbers and colours |
| [state.schema.json](state.schema.json) | State dump schema |
| [actions.json](actions.json) | Actions and default bindings |
| [tests/](tests/) | Behavioural tests |
| [replays/](replays/) | Sample replays |
| [../../assets/pong/](../../assets/pong/) | Shared assets |
