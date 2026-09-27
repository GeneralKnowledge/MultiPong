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

**Status: complete for headless sims in Python, JS, and Rust (incl. offline AI)**

- `reference/pong/` — Python simulation + AI + tests
- `reference/js/` — JavaScript/Node port + AI + tests
- `reference/rust/` — Rust port + AI + `run_tests` binary
- `specs/pong/AI_SPEC.md` — canonical `simple_track` offline AI
- `tools/comparison/run_all_tests.sh` — runs all three

**Exit criteria:** All canonical tests (sim + AI) pass in each reference language; any spec ambiguities found are fixed in `specs/pong/` before further ports spread.

If the spec is wrong, **fix the spec** — do not quietly diverge a reference.

---

## Phase 2b — Cross-platform multiplayer

**Status: complete for the thin vertical slice**

- Decision: **authoritative WebSocket + JSON** (not P2P / lockstep) — see [MULTIPLAYER.md](MULTIPLAYER.md)
- `specs/pong/PROTOCOL.md` — wire protocol
- `backend/server.py` — tiny server using the reference sim
- `examples/*` — minimal client per target platform

**Exit criteria:** Two different clients can join one room and see the same server `GameState`.

---

## Phase 3 — Lightweight stack clients (dual-mode)

**Status: complete for Python / JS / Rust**

Polished clients under `examples/{python,javascript,rust}/`:

- **Online** — render authoritative server state
- **Offline** — local `reference/*` sim + shared `simple_track` AI (seat 2)

Stay on Pong until most language/engine ports exist; do not start the next game early.

---

## Phase 4 — Additional engines (still Pong)

**Goal:** Expand coverage without changing the Pong rules. Each new client should prefer dual-mode when a reference sim exists in that language.

**Done in-repo (Cursor-friendly stacks):**

- Phaser 3 — `examples/phaser/` (reuses JS sim + AI)
- Bevy 0.15 — `examples/bevy/` (reuses Rust `pong_sim` + AI)
- Godot 4.7 — `examples/godot/` (GDScript `PongSim` + AI; runs in Cursor)
- Love2D 11 — `examples/lua/` (Lua sim + AI + vendored WS)

**Still open (need a local editor / human for real projects):**

1. Unity (C#)
2. GameMaker (GML)
3. Unreal C++ / Blueprints
4. RPG Maker (JavaScript)

These are **local-IDE** ports of the **same basic dual-mode Pong** (not richer games). How AI and humans split IDE handoff — without adding features or reinventing host basics — is in [ENGINE_WORKSPLIT.md](ENGINE_WORKSPLIT.md).

**Exit criteria per engine:** Same as Phase 3 (parity with lightweight clients); plus a minimal Human setup checklist from ENGINE_WORKSPLIT.

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
3. Ports (lightweight examples first; full `implementations/` when an editor earns its keep)

Discover which concerns stay portable (rules, timing, input actions) and which become engine-specific (3D cameras, complex animation, navmeshes, etc.).

Engine choice does not expand scope: a platformer in Unreal should still aim at one faithful simple version. Read [ENGINE_WORKSPLIT.md](ENGINE_WORKSPLIT.md) for AI vs human IDE handoff; the GAME_SPEC must say if engine physics is allowed.

---

## Explicit non-roadmap

Not planned:

- Universal custom engine
- Mandatory ECS layer
- Matchmaking clouds, accounts, databases, rollback netcode
- Asset store / marketplace
- Commercial release pipeline

(The tiny authoritative WebSocket server in `backend/` **is** planned and implemented.)

---

## Contribution alignment

Work should target the **current** phase’s exit criteria before skipping ahead. Spec changes that affect numbers or rules require updating tests and bumping the game spec `version` in `constants.json`.
