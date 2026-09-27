# Architecture

This document defines the engine-independent architecture for all games in this repository.

It answers: *how do we structure a game so that many engines can implement the same behaviour?*

---

## 1. Core principle

```text
Canonical game specification  →  faithful engine implementations
```

Two layers exist for every game:

### Canonical game design (shared)

Engine-independent definition of:

- game rules
- game state
- entities and properties
- numerical constants
- simulation behaviour
- collision rules
- input **semantics** (actions, not keys)
- game modes / states
- win / loss conditions
- timing (fixed timestep)
- deterministic behaviour

Authoritative sources live under `specs/<game>/`.

### Engine implementation (per technology)

Technology-specific translation of:

- rendering
- input APIs (keyboard, gamepad, etc.)
- audio playback
- scenes / prefabs / nodes / actors / events
- asset loading and import settings
- project configuration
- UI chrome and menus (layout may be native; content must match)
- engine lifecycle (init, update, shutdown)
- packaging and distribution

The implementation **translates** the specification. It does not redesign the game.

---

## 2. Simulation architecture

Every implementation should organise logic conceptually as:

```text
┌─────────────────────────────────────────────────────────┐
│                     ENGINE ADAPTER                       │
│  (lifecycle, window, asset load, platform glue)          │
└───────────────────────────┬─────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
    ┌─────────┐      ┌────────────┐     ┌──────────┐
    │  INPUT  │      │   AUDIO    │     │ RENDERING│
    │  map    │      │  (cues)    │     │  (draw)  │
    └────┬────┘      └─────▲──────┘     └────▲─────┘
         │                 │                  │
         ▼                 │                  │
    ┌─────────────────────────────────────────┴───────┐
    │              AUTHORITATIVE SIMULATION            │
    │                                                  │
    │   GameState  →  apply InputFrame  →  step rules  │
    │   → collision / scoring  →  new GameState        │
    │   → emit Events (score, hit, game_over, …)       │
    └──────────────────────────────────────────────────┘
```

### Explicit separation

| Concern | Responsibility | Depends on engine? |
| --- | --- | --- |
| **INPUT** | Poll devices → produce canonical `InputFrame` | Yes (device APIs) |
| **SIMULATION** | Pure rules: state + inputs + dt → new state + events | **No** |
| **GAME STATE** | Authoritative data for the current tick | No (schema is shared) |
| **RENDERING** | Draw current state | Yes |
| **AUDIO** | Play cues from events | Yes |
| **ENGINE ADAPTER** | Boot, loop, assets, quit | Yes |

### Why separate them?

1. **Portability** — Simulation can be reimplemented in any language without pulling in engine physics or scene graphs.
2. **Testability** — Canonical tests run against simulation alone (no window required).
3. **Comparability** — Two engines can dump `GameState` after N ticks and compare.
4. **Clarity** — Prevents “the physics engine did something different” bugs.

**Rule:** For games in this project (starting with Pong), **do not** use Unity Physics, Unreal Chaos/PhysX, Godot Physics, Box2D bindings, etc. for authoritative collision unless the canonical spec explicitly says so. Implement the maths in the specification.

Rendering and audio **may** use whatever the engine provides.

---

## 3. Canonical units

All specs use these units unless a game document states otherwise.

| Quantity | Unit | Symbol |
| --- | --- | --- |
| Distance | pixels | px |
| Velocity | pixels per second | px/s |
| Acceleration | pixels per second² | px/s² |
| Time | seconds | s |
| Simulation step | fixed timestep | typically `1/60` s |
| Angles (if used) | degrees, clockwise from +X, unless specified | ° |
| Colour | sRGB hex `#RRGGBB` or `#RRGGBBAA` | — |

### Coordinate system (canonical 2D)

```text
(0,0) ──────────────────────────────► +X
  │
  │         playfield
  │
  ▼
 +Y
```

- Origin: **top-left** of the playfield.
- +X: right.
- +Y: **down**.

Entity positions are defined per-game (Pong uses **centre** of ball and paddles; see `specs/pong/GAME_SPEC.md`).

### Engine conversion

| Engine convention | Conversion from canonical |
| --- | --- |
| Y-up (Unity 2D orthographic, Unreal often) | `y_engine = playfield_height - y_canonical` for positions; negate `vy` when converting velocity |
| Metres / Unreal units | Prefer orthographic/pixel cameras so **1 unit = 1 px**. If impossible, scale by a documented factor `S` and keep simulation in px internally |
| Integer-only pixel engines | Simulate in floating point as specified; round **only** for drawing |
| Sub-pixel | Simulation uses IEEE-754 binary64 (`double`) where available; see Determinism |

Constants in the spec are always in canonical units:

```text
BALL_SPEED_INITIAL = 300   # px/s
```

Never store engine-specific “feels right” numbers as the source of truth.

---

## 4. Fixed timestep simulation

All games use a **fixed** simulation timestep:

```text
TICK_RATE = 60
DT        = 1 / 60      # seconds per tick
```

### Update loop (conceptual)

```text
accumulator = 0
while running:
    frame_time = clamp(real_delta, 0, MAX_FRAME_TIME)
    accumulator += frame_time

    input_frame = sample_and_map_input()   # held actions for this display frame

    while accumulator >= DT:
        simulation.step(state, input_frame, DT)
        accumulator -= DT

    alpha = accumulator / DT               # optional interpolation for rendering
    render(state, alpha)                   # interpolation is visual-only
    play_audio(events)
```

Notes:

- **Simulation never uses variable `dt` for rules.** Always `DT = 1/60`.
- If the machine stalls, clamp `frame_time` (e.g. max 0.25 s) and optionally spiral-limit steps per frame (e.g. max 5) to avoid death spirals. Document any spiral limit; default for Pong: **max 5** simulation steps per display frame; discard excess accumulator beyond that (prefer stability over catching up during extreme stalls).
- Rendering interpolation (`alpha`) must **not** write back into authoritative state.

### Headless mode

Every implementation should be able to run simulation **without** rendering:

```text
load initial state
for each tick:
    apply InputFrame (from test, replay, or stub)
    step(DT)
    optionally serialize GameState
```

This is required for automated tests and future comparison tooling.

---

## 5. Determinism

The project aims for **practical determinism**: identical inputs + identical initial state → identical authoritative state sequences across implementations, within defined tolerances.

### Requirements

| Requirement | Detail |
| --- | --- |
| Fixed timestep | Always `DT = 1/60` |
| Deterministic initial state | Spec defines exact starting values after reset / serve |
| No hidden randomness | Pong Phase 1 has **no RNG**. When later games need RNG, use a documented PRNG (e.g. xorshift32) seeded from the spec |
| Pure simulation | No wall-clock reads, no engine physics, no undefined iteration order over hash maps in sim code |
| Headless runnable | Simulation without GPU/window |

### Floating-point policy

Absolute bit-identical floats across Python / C# / C++ / Lua / JS are **not** guaranteed.

Policy:

1. Simulate with **binary64** (`double`) when the language allows. On platforms without doubles for game maths, use the highest precision available and document it.
2. Compare states with **absolute tolerances** defined in tests (Pong default: positions `1e-4` px, velocities `1e-4` px/s, unless a test specifies otherwise).
3. Do **not** introduce epsilon “fudge” into collision logic beyond what the spec states.
4. Prefer simple arithmetic (add, multiply, negate) over trig where possible. When trig is required, use standard library functions and document expected precision.

### Replay / comparison pipeline (design target)

```text
Input sequence (replay file)
        ↓
   Simulation (per engine, headless)
        ↓
State sequence (JSON lines or dump)
        ↓
   Comparison tool
```

Identical replays should produce matching state dumps within tolerance. See [TESTING.md](TESTING.md).

---

## 6. Canonical game state

Every game defines an authoritative `GameState` object. Pong’s schema is in `specs/pong/state.schema.json`.

### State categories

| Category | Meaning | Examples (Pong) | Persisted in dump? |
| --- | --- | --- | --- |
| **Authoritative simulation** | Required to step the game | `mode`, `tick`, scores, ball pos/vel, paddle Y | Yes |
| **Derived** | Computable from authoritative | AABB rects, “who is winning” | Optional; must match if present |
| **Rendering-only** | Visual smoothing, particles, flash timers that do not affect rules | Screen-shake offset, score pop animation | No (must not affect sim) |
| **Engine-specific** | Handles, node refs, textures | Godot `NodePath`, Unity `GameObject` | No |

**Invariant:** Given only authoritative state + an `InputFrame`, `step` is fully determined.

### Conceptual Pong state

```text
GameState
├── mode            # MENU | PLAYING | POINT_SCORED | PAUSED | GAME_OVER
├── tick            # u32, increments each sim step while mode allows
├── elapsed_time    # tick * DT (derived; may be stored for convenience)
├── point_pause_remaining  # seconds; used in POINT_SCORED
├── ball
│   ├── x, y        # centre, px
│   ├── vx, vy      # px/s
│   └── active      # bool; false during some pauses
├── player1
│   ├── y           # paddle centre Y
│   └── score
├── player2
│   ├── y
│   └── score
├── serving_player  # 1 or 2; who serves next
└── winner          # 0 none, 1, or 2
```

The same conceptual fields must exist in every implementation (names may follow language conventions; dumps use the schema field names).

---

## 7. Input abstraction

Simulation never reads raw keys. It only sees **canonical actions**.

### Action model

Each tick, an `InputFrame` indicates which actions are **held** (and optionally which were **pressed** this tick for edge-triggered actions).

Pong actions (`specs/pong/actions.json`):

| Action | Typical use |
| --- | --- |
| `P1_UP` | Player 1 move up (toward y = 0) |
| `P1_DOWN` | Player 1 move down |
| `P2_UP` | Player 2 move up |
| `P2_DOWN` | Player 2 move down |
| `CONFIRM` | Start / dismiss / continue (edge) |
| `PAUSE` | Toggle pause (edge) |
| `RESTART` | Return to menu / reset (edge) |

Default key bindings are documented in the game spec for human playability, but they are **bindings**, not simulation inputs.

```text
Keyboard / Gamepad  →  Input Adapter  →  InputFrame { actions }
                                              ↓
                                         Simulation
```

Edge-triggered actions (`CONFIRM`, `PAUSE`, `RESTART`) fire once when transitioning from not-held to held, or via an explicit `pressed` set in the `InputFrame`. Held movement actions apply every tick while active.

---

## 8. Rendering abstraction

There is **no** universal rendering API.

Each engine implements the visual requirements natively:

| Requirement | Notes |
| --- | --- |
| Draw playfield background | Solid colour per spec |
| Draw centre line (optional dashed) | Spec dimensions |
| Draw paddles | Rectangles (or shared sprite) at paddle centres |
| Draw ball | Circle or shared sprite |
| Draw score / UI text | Font from shared assets; string content from spec |
| Draw menu / pause / game-over overlays | Copy from spec |

Visual targets (colours, sizes, fonts) live in the game spec and `assets/`. Engines may use meshes, sprites, or draw-calls — the **pixels should look substantially the same**.

### Shared presentation rules

- Playfield size: exactly as specified (window may add letterboxing).
- Colours: from `constants.json`.
- Font: shared file under `assets/<game>/fonts/` when practical; if an engine cannot load it, use a closest built-in and document the deviation.
- No engine may change paddle/ball sizes “to look better.”

---

## 9. Audio abstraction

Simulation emits **events**; audio adapters play sounds:

| Event (Pong) | Sound asset |
| --- | --- |
| `paddle_hit` | `assets/pong/audio/paddle_hit.*` |
| `wall_hit` | `assets/pong/audio/wall_hit.*` |
| `score` | `assets/pong/audio/score.*` |
| `game_over` | `assets/pong/audio/game_over.*` |
| `ui_confirm` | `assets/pong/audio/ui_confirm.*` |

Missing audio files during early phases: implementations may use short programmatic beeps of similar length, documented as temporary.

Audio must not affect simulation.

---

## 10. Events

Each `step` may produce an ordered list of events. Events are:

- used for audio and UI feedback
- useful in tests (“expect a `score` event”)
- **not** required to round-trip into state (state alone is authoritative)

---

## 11. Engine adapter responsibilities

The adapter owns:

1. Create window / context at the correct playfield resolution (or letterboxed).
2. Load shared assets (or copies thereof).
3. Map platform input → `InputFrame`.
4. Run the fixed-timestep loop.
5. Call `render` and audio.
6. Expose a **headless** entry point for tests.
7. Optionally dump state / read replays.

It must not embed game rules outside the simulation module.

---

## 12. Complexity budget

Allowed:

- plain structs / classes for state
- a single `step(state, input, dt)` function (or equivalent)
- thin input / render / audio adapters
- JSON test and replay files

Not allowed (project-wide):

- a custom multi-engine runtime
- mandatory ECS
- networking / multiplayer
- cloud services / databases
- heavy shared frameworks

If a pattern needs more than a short explanation in the game spec, it is probably too heavy for this experiment.

---

## 13. Multi-game evolution

Architecture stays the same as games grow (Snake, Breakout, …):

1. New folder under `specs/<game>/`.
2. Same unit system, timestep policy, input-action model, test/replay formats.
3. Simulation remains authoritative and engine-physics-free unless the spec says otherwise.
4. Complexity increases in the **spec**, not via a mega-framework.

See [ROADMAP.md](ROADMAP.md).
