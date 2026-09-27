# Roadmap

Staged plan for the multi-engine games project. Phases are sequential in intent; later phases may start stubs earlier if they do not invalidate the spec.

---

## Phase 0 — Project architecture and documentation

**Status: complete in this repository revision**

- Philosophy and layer separation
- Repository layout
- Architecture (units, simulation, determinism, input, rendering)
- Implementation rules and faithfulness criteria
- Testing and comparison **design** (not tooling yet)

**Exit criteria:** A new contributor can explain canonical vs engine layers without asking for design decisions.

---

## Phase 1 — Canonical Pong specification

**Status: complete in this repository revision**

- `specs/pong/GAME_SPEC.md`
- `constants.json`, `state.schema.json`, `actions.json`
- Initial behavioural tests and sample replay schema
- Shared asset directory layout (assets themselves may be placeholders)

**Exit criteria:** Two engineers can implement Pong independently from the spec alone.

---

## Phase 2 — Reference implementation

**Goal:** One simple, readable implementation used to validate the spec.

**Recommended:** `reference/pong/` in Python (plain or Pygame), with:

- headless simulation module
- optional windowed play
- test runner that executes `specs/pong/tests/`

**Exit criteria:** All canonical tests pass; any spec ambiguities found are fixed in `specs/pong/` before multi-engine ports spread.

If the spec is wrong, **fix the spec** — do not quietly diverge the reference.

---

## Phase 3 — First translated implementation

**Goal:** Prove the methodology with a second technology.

**Suggested order:** Pygame (if reference was headless-only) **or** Love2D / Godot — pick one 2D-friendly stack.

**Exit criteria:** Tests pass; README documents mapping; no engine physics for gameplay.

---

## Phase 4 — Additional engines

**Goal:** Expand coverage without changing the Pong rules.

Priority suggestion (adjust to contributor interest):

1. Godot (GDScript)
2. Phaser (TypeScript) or Love2D (Lua)
3. Unity (C#)
4. Bevy (Rust)
5. GameMaker (GML)
6. Unreal C++ / Blueprints
7. RPG Maker (JavaScript)

**Exit criteria per engine:** Same as Phase 3.

---

## Phase 5 — Cross-engine deterministic testing

**Goal:** Replays and state traces.

- Flesh out replay runners
- Agree on JSONL trace format (see [TESTING.md](TESTING.md))
- Add longer replays (full point, full match)

**Exit criteria:** At least two engines produce traces for the same replay within epsilon.

---

## Phase 6 — Automated comparison tooling

**Goal:** `tools/comparison` aggregates reports.

Example:

```text
compare pong
→ table of PASS/FAIL/MISSING per implementation
```

Optional: CI job that runs available engines on a supported host.

**Exit criteria:** One command summarizes faithfulness across checked-in reports.

---

## Phase 7 — More complex games

**Goal:** Increase canonical complexity gradually.

Suggested progression (design later, not now):

```text
Pong
  → Snake
  → Breakout
  → Asteroids
  → Top-down shooter
  → Platformer
  → Colony simulation
```

Each new game:

1. Spec + constants + tests first
2. Reference implementation
3. Ports

Discover which concerns stay portable (rules, timing, input actions) and which become engine-specific (3D cameras, complex animation, navmeshes, etc.).

---

## Explicit non-roadmap

Not planned:

- Universal custom engine
- Mandatory ECS layer
- Online multiplayer infrastructure
- Asset store / marketplace
- Commercial release pipeline

---

## Contribution alignment

Work should target the **current** phase’s exit criteria before skipping ahead. Spec changes that affect numbers or rules require updating tests and bumping the game spec `version` in `constants.json`.
