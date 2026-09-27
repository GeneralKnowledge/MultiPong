# Engine work-split: AI vs human

**Purpose:** How AI coding agents and humans should share work when porting to IDE-centric engines (Unity, Unreal, GameMaker, RPG Maker, full Godot projects, etc.).

**This document does not implement anything.**

Related: [ARCHITECTURE.md](ARCHITECTURE.md), [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md), [ROADMAP.md](ROADMAP.md).

---

## 1. First principle: same simple game

An Unreal (or Unity, GameMaker, …) port of Pong is **not** a richer product. It is the **same basic game** as the Python / JavaScript / Love2D clients:

| Must match the lightweight clients | Must **not** add “because Unreal can” |
| --- | --- |
| Same rules, constants, modes, scores | Extra modes, power-ups, menus, campaigns |
| Same seat controls and PROTOCOL | Unreal Replication / Steam / matchmaking |
| Same offline AI (`simple_track`) | “Smarter” bots, difficulty trees |
| Same playfield look (Very similar) | AAA lighting, Niagara juice, cinematic cameras |
| Dual-mode: offline sim **or** thin online client | A second netcode design |

**Success** = faithfulness tests + the same beginner experience.  
**Failure** = a showcase that drifts from `specs/pong/`.

We use a “proper” engine only as a **host** (window, draw, input, project files) — not as permission to grow scope.

---

## 2. Why these ports still need a human

The game stays simple; the **tooling** does not. Cloud agents and CI usually lack a licensed Unity/Unreal editor, GPU cooks, and click-through import dialogs.

So the split is about **who can touch which files**, not about building a bigger game:

| Layer | Who | Notes |
| --- | --- | --- |
| Spec, `step()`, tests, PROTOCOL glue | AI (and review) | Same as any other port |
| Draw paddles/ball/scores from `GameState` | AI scripts + minimal scene | Rectangles / simple sprites are enough |
| Create `.uproject` / `.unity` / wire components in the IDE | Human | Agent stops at code + checklist |
| Packaging / store / plugins | Human (later, optional) | Not required for “port done” |

Keep the scene deliberately dumb: orthographic (or flat) view, two paddles, one ball, score text, HUD line — parity with Pygame, not a sample from the Unreal marketplace.

---

## 3. The wheel test (still apply — but for *hosting*, not features)

Before writing custom infrastructure, ask:

> Does the engine already provide this **host** capability so we can stay focused on the same simple game?

| Concern | Use the engine | Keep in our spec / sim |
| --- | --- | --- |
| Window, loop, draw sprites/meshes | ✓ | |
| Keyboard / gamepad → our seat actions | ✓ map only | |
| Basic audio play-one-shot (if we add SFX later) | ✓ | |
| Project / packaging | ✓ | |
| **Rules, scores, modes, tick, collision maths** | | ✓ always (Pong) |
| **Online authority** | | shared server + PROTOCOL |
| **Offline AI** | | [AI_SPEC.md](specs/pong/AI_SPEC.md) only |

**Do not reinvent:** a custom renderer, a second UI framework, a second websocket protocol, or a physics engine for Pong.

**Also do not “use the wheel” as scope creep:** Character Movement, Chaos, Gameplay Ability System, common UI frameworks, etc. are available in Unreal — **leave them unused** for Pong unless a future GAME_SPEC says otherwise.

Pong forbids engine physics for ball/paddles ([IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) Rule 2). Draw what `step()` (or the server) already decided.

---

## 4. Layer ownership (unchanged)

```text
specs/<game>/          → truth (rules, constants, tests)
reference/             → headless sim + AI
backend/               → online authority
examples/              → thin dual-mode clients (often Cursor-runnable)
implementations/       → same game inside an engine project (often needs local IDE)
```

For Unity/Unreal/etc.:

- **Exact** behaviour = same tests as Python/JS.
- **Very similar** presentation = same layout/colours; engine-native draw is fine.
- **Engine-specific** structure (Actors, prefabs) is fine **as long as behaviour stays simple**.

---

## 5. What AI agents should own

AI is strongest on **text, structure, and headless verification**:

- Spec / constants / JSON tests / reference sims
- Pure `step()` + `ai_held` in the engine language (no editor dependency)
- Thin online adapter: join, send seat `input`, render received `state`
- Coordinate conversion (Y-up ↔ Y-down) at the draw boundary only
- README with **AI-maintained** file list and **Human setup (editor)** checklist
- Stub components with `TODO(human): assign this reference in the editor`

AI should **not** claim the port is finished without the JSON test pack, and should **not** expand scope with engine-only systems.

When there is no editor in the environment, stop at **compilable scripts + instructions**.

---

## 6. What humans should own

Minimal editor work to host the same game:

| Task | Why |
| --- | --- |
| Create / open the engine project | Binary / IDE state |
| Drop in a blank level / orthographic camera | One-time setup |
| Attach AI-written components; assign paddle/ball/score references | Inspector wiring |
| Import shared `assets/pong/` if used (nearest-neighbour, correct size) | Import UI |
| Press Play; smoke offline + online vs Python/JS | Eyes + local server |
| Optional: package a build | SDKs / licenses |

Humans should **not** add modes, polish systems, or rewrite speeds/scores in the Inspector. Tunables stay mirrored from `constants.json`.

Skip for a basic port: lighting art passes, animation graphs, navmesh, Niagara, UMG menus beyond the same MENU/PAUSE/GAME_OVER text the other clients show.

---

## 7. Suggested collaboration workflow (Pong in Unreal/Unity/…)

```text
1. Spec + tests + reference sim already exist
2. AI ports headless sim + AI + thin net client in C++/C#/GML/…
3. AI documents a minimal scene checklist (camera, 3 meshes/sprites, text)
4. Human creates empty project, wires those pieces, hits Play
5. Run specs/pong/tests (headless where possible) + two-client online smoke
6. README: Known differences = coordinate/API only — not design changes
```

Example README fragment:

```markdown
### Goal
Same dual-mode Pong as `examples/python` — not an Unreal feature demo.

### Human setup (editor)
1. Create blank project (no template gameplay)
2. Add orthographic camera; orthographic width = playfield
3. Spawn/update two paddle meshes + ball from `GamePresenter`
4. Bind W/S/↑/↓/Enter/P/R to seat actions
5. Play offline; then online against `backend/server.py`

### AI-maintained
- Simulation / AI / PROTOCOL client code
- constants from `specs/pong/constants.json`
```

---

## 8. Later games (Phase 7) — separate from “use Unreal for Pong”

[ROADMAP.md](ROADMAP.md) Phase 7 may add Snake → platformer → etc. That is **new specs**, not permission for the Pong Unreal port to grow.

When a future GAME_SPEC is more complex:

- Still prefer **one simple faithful version per engine**, not a showcase.
- The GAME_SPEC must say if engine physics/pathing is allowed; default remains custom `step()`.
- AI vs human split stays the same: AI owns rules/tests/adapters; human owns IDE content that cannot be done in Cursor.

Do not open Unity/Unreal “to unlock features.” Open them to prove the **same** game runs there.

---

## 9. Per-engine notes (basic Pong)

| Target | AI | Human (minimal) |
| --- | --- | --- |
| **Unity** | C# sim, tests, WS client, presenter script | Empty scene, assign refs, Input System bindings |
| **Unreal C++** | Sim module, JSON PROTOCOL, tick that calls `step` or applies server state | Blank level, pawn/HUD widgets for paddles/ball/score |
| **Unreal Blueprints** | Prefer C++ sim; BP only for presenting state | Wire “on state updated → set locations” |
| **Godot** | Prefer `examples/godot/` dual-mode client | Only if packaging a fuller project tree |
| **GameMaker** | GML join/input/draw from state | Room size 800×600, sprites, WS extension |
| **RPG Maker** | JS plugin wrapping the shared client | Blank map / custom scene host — no battle system |

Stubs in `examples/{csharp,unreal,gamemaker,rpgmaker}/` document the contract until someone opens the IDE. They are not invitations to add features.

---

## 10. Multiplayer reminder

Same as every other client ([MULTIPLAYER.md](MULTIPLAYER.md)):

- Seat-relative input over WebSocket JSON
- Server owns Exact state online
- Do **not** invent Unreal replication, P2P, or a second protocol for Pong

---

## 11. Checklist (basic engine port)

- [ ] Target behaviour = existing dual-mode clients (no extra features)
- [ ] `step()` / server state drives positions — engine physics off for gameplay
- [ ] Headless (or documented) pass of `specs/pong/tests/`
- [ ] Online speaks PROTOCOL against `backend/server.py`
- [ ] README lists AI-maintained vs Human setup
- [ ] Known differences are API/coordinates only
- [ ] No marketplace templates, ability systems, or “improved” AI

---

## 12. One-line summary

**Unreal/Unity/etc. get the same simple Pong — AI writes the portable rules and thin adapters; a human wires a minimal project in the IDE; neither side uses the engine as an excuse to add features or reinvent hosting basics.**
