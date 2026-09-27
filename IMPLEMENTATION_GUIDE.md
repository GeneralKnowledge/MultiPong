# Implementation Guide

Rules and templates for translating a canonical game into an engine.

If five developers each pick a different engine and follow this guide plus `specs/<game>/`, they should produce the **same game** in the Exact / Very similar sense defined below.

---

## What “faithful” means

### Exact (MUST match)

| Area | Criterion |
| --- | --- |
| Game rules | Mode transitions and scoring identical to the spec |
| State transitions | Same inputs → same authoritative fields within epsilon |
| Numerical constants | Values from `constants.json`, not reinvented |
| Input semantics | Canonical actions only inside simulation |
| Collision behaviour | Maths from the spec; no substitute physics |
| Timing | Fixed `DT = 1/60`; tick rules per mode |

**Measurable:** all `specs/<game>/tests/*.json` PASS.

### Very similar (SHOULD match)

| Area | Criterion |
| --- | --- |
| Visual layout | Playfield 800×600; entity sizes/positions; score/menu placement |
| Colours | Spec hex colours |
| Animation | No extra gameplay-affecting motion; optional render interpolation only |
| Audio | Correct event → cue mapping; similar short SFX |
| UI copy | Exact strings from `constants.json` / GAME_SPEC |

**Measurable:** manual checklist in the engine README; document any font fallback.

### Engine-specific (MAY differ)

| Area | Examples |
| --- | --- |
| Scene structure | Prefabs, Nodes, Actors, Events, Scenes |
| Project files | `.unity`, `.godot`, `.uproject`, etc. |
| Asset import | Compression, filtering, PNG vs import settings |
| Editor setup | How to open the project |
| Packaging | Exe, web build, apk |
| Source style | Idiomatic Python vs C# vs Rust |

**Not a failure:** different code structure that preserves semantic behaviour.

Avoid subjective claims (“feels like Pong”). Use tests and checklists.

---

## Implementation rules

### Rule 1 — Do not redesign

Do not change speeds, sizes, win score, bounce angle, or modes because an engine tutorial does it differently.

### Rule 2 — Do not rely on engine physics unless specified

Pong collision is explicit. Unity Physics / Unreal / Godot Physics / Box2D MUST NOT authoritatively move the ball or paddles.

### Rule 3 — Preserve numbers

Copy from `constants.json`. If a unit conversion is required (Y-up), convert at the adapter boundary; keep simulation in canonical units.

### Rule 4 — Preserve behaviour

Equivalent `InputFrame` sequences must yield equivalent `GameState` sequences within tolerance.

### Rule 5 — Engine-native presentation is allowed

Prefabs, Nodes, Actors, tilemaps, draw calls — all fine for rendering and organisation.

### Rule 6 — Do not force identical source code

Semantic equivalence, not syntax equivalence. Write idiomatic code for the language.

### Rule 7 — Simulation must be headless-capable

Separate pure simulation from rendering so tests can run without a window.

### Rule 8 — Document deviations

Any intentional or forced difference goes in the engine `README.md` under **Known differences**.

### Rule 9 — No networking, cloud, or mega-frameworks

Keep the implementation understandable by one developer.

### Rule 10 — Shared assets first

Use files from `assets/<game>/` (or copies). Do not replace paddle/ball sizes with different art that changes collision bounds.

---

## Recommended module split

Conceptual packages (names may vary):

```text
simulation/     # GameState, step(), events — no engine imports
input/          # device → InputFrame
rendering/      # draw state
audio/          # event → play
app/            # lifecycle, loop, headless entry
```

Circular dependency from simulation → engine APIs is forbidden.

---

## Engine implementation template

```text
implementations/<engine>/
├── README.md                 # Required
├── reports/                  # Test reports (generated)
├── src/                      # or engine-typical paths
│   ├── simulation/
│   ├── input/
│   ├── rendering/
│   └── audio/
├── assets/                   # Optional local copies / import cache
│   └── README.md             # Note: sourced from ../../assets/pong
├── tests/                    # Engine-side harness
└── <project files>           # .godot, *.csproj, project.godot, etc.
```

Adapt freely (Unity may use `Assets/Scripts/...`; Godot `scripts/`; Unreal `Source/`). The **README** must map folders to the conceptual split above.

---

## Required README sections

Every `implementations/<engine>/README.md` MUST include:

1. **Engine & language** — name, version, language
2. **Status** — not started / in progress / tests passing
3. **How to install & run** — exact commands
4. **How to run tests** — headless commands
5. **Spec mapping** — table: canonical concept → engine construct
6. **Coordinate conversion** — if Y-up or non-pixel units
7. **Known differences** — list or “none”
8. **Test results** — link to latest `reports/` or paste summary
9. **Constants source** — confirm `specs/pong/constants.json` is used

---

## Suggested mapping examples

| Canonical | Pygame | Godot | Unity | Unreal |
| --- | --- | --- | --- | --- |
| GameState | dataclass / dict | Ref-counted object or Dictionary | C# class | USTRUCT / plain struct |
| step() | function | method on RefCounted | static/class method | free function / subsystem |
| Render paddle | `pygame.draw.rect` | `ColorRect` / `draw_rect` | Sprite / UI Image / Mesh | UPaperSprite / HUD |
| Input | `pygame.key` | `Input` map | Input System / old Input | Enhanced Input |
| Loop | manual clock | `_physics_process` **calling fixed sim** | `FixedUpdate` **or manual accumulator** | Tick with fixed dt |

**Caution:** Godot’s `_physics_process` and Unity `FixedUpdate` default rates may not be 60. Either configure them to 60 Hz **or** ignore them for gameplay and drive `step(DT)` from your own accumulator. Authoritative dt remains `1/60`.

---

## Implementation order (per engine)

1. Port `GameState` + `step` + mode machine (no graphics).
2. Wire test runner; pass all JSON tests.
3. Add rendering (paddles, ball, scores, modes).
4. Map input bindings.
5. Add audio events.
6. Polish README and record report.
7. Only then claim the port is complete.

---

## Placeholder engines

Directories under `implementations/` are reserved. Create a README when starting a port; until then a short stub is enough.

Potential targets:

- `pygame` — Python
- `godot` — GDScript
- `unity` — C#
- `unreal-cpp` — C++
- `unreal-blueprints` — Blueprints (simulation still MUST follow the same maths; Blueprints may call into C++ for sim if needed for precision)
- `rpgmaker` — JavaScript (plugin / event hybrid)
- `gamemaker` — GML
- `love2d` — Lua
- `phaser` — TypeScript
- `bevy` — Rust

Not all need to exist initially.

---

## Blueprints / visual scripting note

Unreal Blueprints and similar tools often make exact floating-point control harder. Allowed approaches:

1. Implement simulation in C++ and call it from Blueprints for presentation; or
2. Implement simulation carefully in Blueprints with doubles where available and document precision.

The **tests** still decide faithfulness.
