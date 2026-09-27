# Engine work-split: AI vs human

**Purpose:** Guidance for ports that need a *real* game engine (Unity, Unreal, Godot editor projects, GameMaker, RPG Maker, etc.) — not another thin Canvas/Pygame client.

**This document does not implement anything.** It records how we expect AI coding agents and humans to divide labour so we stay faithful to the spec **without reinventing features the engine already ships**.

Related reading: [ARCHITECTURE.md](ARCHITECTURE.md), [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md), [ROADMAP.md](ROADMAP.md) Phase 7.

---

## 1. When a “proper engine” is warranted

Pong fits lightweight stacks (Pygame, browser canvas, Love2D, Bevy, headless-friendly Godot). Later games in the roadmap (platformer, colony sim, 3D-ish shooters, RPG Maker–style adventures) start to need:

| Need | Why a full engine helps |
| --- | --- |
| Scenes / levels | Tilemaps, room transitions, streaming, editor placement |
| Animation | Skeletons, blend trees, sprite sheets, state machines |
| Audio mixing | Buses, spatial audio, music layers |
| UI systems | Canvas/UMG/Control trees, localisation hooks |
| Content pipelines | Import settings, atlases, addressables, cooked builds |
| Navigation / AI pathing | Navmeshes, pathfinding volumes (when the *spec* allows engine pathing) |
| Packaging | Console/PC/mobile export, plugin ecosystems |

**Rule of thumb:** if most of the work is *content and presentation inside an editor*, treat it as an engine port. If most of the work is *pure `step()` + draw rectangles*, stay on a lightweight example.

---

## 2. The wheel test (do not reimplement)

Before writing custom code, ask:

> Does the engine already provide this in a way that **does not change canonical game rules**?

| Concern | Prefer engine | Prefer our sim / spec |
| --- | --- | --- |
| Drawing sprites / meshes | ✓ | |
| Camera, lighting, post-FX | ✓ | |
| Asset import, atlases, compression | ✓ | |
| Editor scene layout, prefabs, tile painting | ✓ | |
| UI layout widgets | ✓ | |
| Audio playback / mixing | ✓ | |
| Packaging / export | ✓ | |
| Input device polling / rebinding UI | ✓ (map to **our** actions) | |
| **Authoritative rules, scores, modes, win/loss** | | ✓ always |
| **Canonical timing (`DT`, tick)** | | ✓ always |
| **Collision / movement when the spec defines maths** | | ✓ (Pong today) |
| **Collision when the spec says “use engine physics with these constraints”** | ✓ under spec constraints | document + tests |
| **Online authority** | | shared server / PROTOCOL |

Pong today forbids engine physics for the ball and paddles ([IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) Rule 2). Future games may *explicitly* allow CharacterController, Rigidbody2D, or navmesh **in the GAME_SPEC** — then using the engine is correct, and reinventing a physics engine in Lua/C# is wrong.

**Never** reimplement for “purity”:

- A full skeletal animation system
- A second UI framework beside the engine’s
- A custom asset cooker
- A second networking stack when PROTOCOL + backend already exist
- A “better” offline AI than [AI_SPEC.md](specs/pong/AI_SPEC.md) (for that game)

---

## 3. Layer ownership (unchanged)

```text
specs/<game>/          → truth (rules, constants, tests)
reference/             → headless sim + AI (language ports)
backend/               → online authority (when multiplayer applies)
examples/              → thin dual-mode clients (Cursor-friendly)
implementations/       → full engine projects (editor + packaging)
```

For engine-heavy games:

- **Exact** behaviour still comes from the spec + tests.
- **Very similar** presentation uses engine-native tools.
- **Engine-specific** structure (prefabs, Blueprints, Actors) is expected and healthy.

---

## 4. What AI agents should own

AI (Cursor / cloud agents / similar) is strongest on **text, structure, and headless verification**. Prefer assigning:

### Spec & methodology

- Draft / refine `GAME_SPEC.md`, `constants.json`, schemas, `AI_SPEC.md`, `PROTOCOL.md`
- Write behavioural JSON tests and reference `step()` ports
- Document Known differences and mapping tables in READMEs

### Simulation & adapters (code)

- Pure simulation modules with **no** engine editor dependency
- Seat-relative input → `InputFrame` mapping tables
- Online client glue: join / input / apply `state` (thin)
- Headless test runners that can run in CI or Cursor when the runtime exists
- Coordinate conversion helpers (Y-up ↔ Y-down) as explicit adapters

### Scaffolding for humans

- Folder layout under `implementations/<engine>/` matching the [template](IMPLEMENTATION_GUIDE.md#engine-implementation-template)
- Stub scripts with clear `TODO(human):` markers for editor-only steps
- “Open this scene / assign these references” checklists in the README
- Import manifests: “place these files from `assets/<game>/` here”

### What AI should *not* pretend to finish alone

- Clicking through Unity/Unreal/Godot import dialogs until “looks right”
- Tuning lighting, bloom, animation curves by eyeball
- Baking navmeshes / lightmaps / occlusion without a GPU editor session
- Certifying console packaging or store submission
- Claiming faithfulness without running the JSON test pack

When the environment has no editor (typical cloud agent), AI stops at **compilable scripts + instructions**; humans complete the project file.

---

## 5. What humans should own

Humans (with a local editor) are strongest on **spatial, visual, and pipeline** work:

| Task | Why human / editor |
| --- | --- |
| Create `.unity` / `.uproject` / `.godot` / GameMaker project | Binary / editor state; agent often cannot validate |
| Import assets with correct PPU, filter, compression | Visual QA |
| Place cameras, canvases, lighting | Aesthetic + engine defaults |
| Wire Inspector references (serialize fields, node paths) | Fragile in pure text diffs |
| Design levels / tilemaps / encounter layouts | Content craft (unless fully data-driven in JSON) |
| Animation clips, blend trees, timeline | Tooling is GUI-first |
| Bake navmesh / lighting | Needs editor + often GPU |
| Audio mix and loudness | Ears + engine mixer |
| Platform export settings | License keys, SDKs, signing |
| Final “feels right” pass against Very similar checklist | Judgment |

Humans should **not** casually rewrite paddle speeds, win scores, or mode machines in the Inspector. Those stay in code fed by `constants.json` (or a generated ScriptableObject / Resource that is a straight dump of the JSON).

---

## 6. Suggested collaboration workflow

```text
1. Spec + tests + reference sim          (AI + human review)
2. AI ports headless sim into engine language
3. AI wires thin online/offline adapters + README checklist
4. Human creates/opens engine project, imports assets, builds scene
5. Human hooks AI-written components onto nodes/prefabs/Actors
6. AI or human runs headless tests; human runs play-mode smoke
7. Document Known differences; check in reports/
```

**Handoff artifact:** every engine README should have a short **“Human setup (editor)”** section listing clicks/commands the AI cannot do in CI, and an **“AI-maintained”** section listing files safe to regenerate from the spec.

Example checklist fragment:

```markdown
### Human setup (editor)
1. Open `MultiPong.unity` / `project.godot` / `.uproject`
2. Import `assets/pong/*` with PPU = … / filter = …
3. Assign Ball View / Paddle Prefab references on `GamePresenter`
4. Press Play; confirm teal “you” outline on local seat

### AI-maintained (safe to regenerate)
- `Scripts/Simulation/*` (must pass specs/pong/tests)
- `Scripts/Net/Protocol.cs` (must match PROTOCOL.md)
- constants dump from `specs/pong/constants.json`
```

---

## 7. Guidance by upcoming game class (Phase 7)

These are **planning thoughts**, not specs. When a game is chosen, its GAME_SPEC will decide physics/nav ownership.

### Snake / Breakout / Asteroids (still mostly 2D logic)

- Still AI-heavy: grid or particle-like sim in pure code; tests dominate.
- Engine optional: use for juice (particles, screenshake) only if Very similar allows.
- Do **not** move to Unity “just because” — keep examples lightweight unless packaging needs it.

### Top-down shooter

- **Spec owns:** spawn rules, damage, invulnerability frames, win/loss, tick rate.
- **Engine owns:** sprites, pooling *presentation*, camera shake, VFX.
- **Split:** bullets can be sim entities (faithful) even if drawn with engine particles.
- AI writes collision rules from the spec; human tunes VFX and feel *without* changing hitboxes.

### Platformer

- Hardest faithfulness trap: CharacterController vs custom AABB.
- GAME_SPEC must say explicitly either:
  - **A)** custom movers (like Pong) — AI implements maths; engine is render-only; or
  - **B)** engine character controller with listed constraints (max slope, coyote time numbers) — human configures controller; AI writes regression tests that assert observed positions within epsilon **or** higher-level invariants (landed, cleared gap).
- Levels: human paints; AI may generate tilemap JSON if the format is text.

### Colony / simulation games

- **Spec owns:** economy equations, agent goals at the action level, day/night rules.
- **Engine owns:** path presentation, building ghosts, UI management screens.
- Prefer data-driven defs (JSON/CSV) AI can edit; human builds panels and icons.
- Avoid AI inventing a second job system if the engine/plugin already has one — wrap it behind the spec’s action names.

### RPG Maker–style

- Engine *is* the product. AI should wrap PROTOCOL / shared JS sim as a plugin; human builds maps, events, and database entries in RPG Maker.
- Do not rebuild the RPG Maker battle system for a Pong-like minigame hosted in a blank map.

---

## 8. Per-engine notes (stubs today)

| Target | AI can do well | Leave for human |
| --- | --- | --- |
| **Unity** | C# `step()`, EditMode/PlayMode test stubs, ScriptableObject from JSON, thin WS client | ProjectSettings, URP/HDRP choice, prefab variants, Input System asset, build profiles |
| **Unreal C++** | Simulation module, Enhanced Input action names, JSON parse of PROTOCOL | `.uproject` plugins, Blueprint wiring, materials, packaging |
| **Unreal Blueprints** | Document “call C++ sim”; generate stub Blueprint graphs as text only if needed | Actual graphs, animation BPs, UI designer |
| **Godot (full project)** | GDScript/C# sim, `.tscn` text scenes for simple trees, headless tests | Import presets, complex scenes, export templates |
| **GameMaker** | GML message sketches, room size constants | IDE resources, sprite origins, extensions for WS |
| **RPG Maker** | JS plugin wrapping `examples/javascript` | Map editor, database, plugin param UI |
| **Love2D / Phaser / Bevy** | Entire dual-mode client (already examples/) | Optional art polish only |

Local-editor stubs under `examples/{csharp,unreal,gamemaker,rpgmaker}/` stay documentation until a human opens the real IDE. AI improves those READMEs and shared protocol helpers; it does not claim a Unity port is “done” from CI alone.

---

## 9. Physics and “using the engine” policy

1. **Default for simple arcade games:** custom `step()` (Pong model). Engine physics off for gameplay bodies.
2. **Allowed when GAME_SPEC says so:** named engine features with frozen parameters in `constants.json` (e.g. `gravity`, `max_slope_deg`, `use_character_controller: true`).
3. **Still forbidden:** silent substitution (“Rigidbody felt better so we dropped the test”).
4. **Tests decide:** if you cannot test it, you do not get to call it Exact.

---

## 10. Multiplayer reminder

Online stays thin ([MULTIPLAYER.md](MULTIPLAYER.md)):

- Clients send seat input; server (or future game’s authority) owns Exact state.
- Engines may use their own sockets **only** as a transport to the same JSON protocol — do not invent Unreal Replication for Pong-class games unless a future GAME_SPEC redesigns networking on purpose.

Offline still needs local `step()` (or a declared engine-physics mode) for faithfulness tests.

---

## 11. Checklist before starting an engine-heavy port

- [ ] GAME_SPEC states what the engine may own (physics, pathing, animation-driven hitboxes, etc.)
- [ ] `constants.json` holds every tunable the AI must not “improve”
- [ ] Headless tests exist for Exact rules
- [ ] README lists **AI-maintained** vs **Human setup (editor)**
- [ ] Wheel test applied: no custom animation/UI/cooker/net stack without cause
- [ ] Online path reuses PROTOCOL + backend (or documents a spec-level exception)
- [ ] Success = tests + Very similar checklist — not “runs in the editor once”

---

## 12. One-line summary

**AI writes the portable truth (spec, sim, tests, thin adapters, checklists). Humans drive the engine editor (scenes, imports, juice, bakes, packaging). Use the engine for presentation and pipelines; never let convenience rewrite the game.**
