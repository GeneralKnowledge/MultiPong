# Multi-Engine Games

**One canonical game specification → multiple faithful implementations.**

This repository defines a methodology for taking a single engine-independent game design and translating it into fundamentally different game engines and frameworks, while preserving rules, numbers, architecture, assets, and behaviour.

The first game is a deliberately small Pong-like title. The goal is not sophistication; it is **semantic equivalence** across technologies.

## Philosophy

| Layer | What it is | What it is not |
| --- | --- | --- |
| **Canonical game design** | Rules, state, entities, constants, simulation, collision, input semantics, win/loss, timing | Rendering APIs, scene graphs, prefabs, packaging |
| **Engine implementation** | Rendering, input APIs, audio playback, scenes/nodes/actors, asset loading, UI chrome, lifecycle, packaging | A redesign of the game |

Implementations **translate** the canonical specification. They must not reinvent paddle speeds, collision response, scoring, or game-state transitions just because an engine offers a convenient physics or template system.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full separation of concerns.

## What this repo contains (now)

| Document / area | Purpose |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Simulation layers, units, determinism, state, input, rendering |
| [MULTIPLAYER.md](MULTIPLAYER.md) | Cross-engine online play: authoritative WebSocket server |
| [GAME_SPEC.md](GAME_SPEC.md) | Spec format + index of games |
| [specs/pong/GAME_SPEC.md](specs/pong/GAME_SPEC.md) | Complete canonical Pong specification |
| [specs/pong/PROTOCOL.md](specs/pong/PROTOCOL.md) | Multiplayer wire protocol |
| [TESTING.md](TESTING.md) | Cross-engine tests, replays, comparison goals |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Rules, faithfulness criteria, per-engine template |
| [ROADMAP.md](ROADMAP.md) | Phased development plan |
| [backend/](backend/) | Tiny authoritative server |
| [reference/pong/](reference/pong/) | Python simulation + test runner |
| [examples/](examples/) | Minimal multiplayer client per platform |

## Repository layout

```text
multi-engine-games/
├── README.md
├── ARCHITECTURE.md
├── MULTIPLAYER.md
├── GAME_SPEC.md
├── TESTING.md
├── IMPLEMENTATION_GUIDE.md
├── ROADMAP.md
├── CONTRIBUTING.md
│
├── specs/pong/                   # Canonical design + PROTOCOL.md
├── assets/pong/
├── reference/pong/               # Python sim + run_tests.py
├── backend/                      # WebSocket server (uses reference sim)
├── examples/                     # Small clients (python, js, godot, …)
├── implementations/              # Full engine ports (stubs / future)
└── tools/
```

Empty implementation directories are placeholders. Add engines as needed; the structure does not require every engine up front.

## Faithfulness at a glance

| Category | Must match |
| --- | --- |
| **Exact** | Rules, state transitions, constants, input semantics, collision maths, tick timing |
| **Very similar** | Layout, colours, fonts, audio cues, UI copy |
| **Engine-specific** | Scene graphs, prefabs, project files, packaging, editor setup |

Full criteria: [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md#what-faithful-means).

## Quick start for implementers

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) and [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md).
2. Read [specs/pong/GAME_SPEC.md](specs/pong/GAME_SPEC.md) end to end.
3. Copy constants from `specs/pong/constants.json` — do not invent new numbers.
4. Implement simulation first (headless-capable), then rendering and audio.
5. Run canonical tests from `specs/pong/tests/` and record results in the engine README.

## Multiplayer quick start

```bash
cd backend && python3 -m pip install -r requirements.txt && python3 server.py
# other terminals / browsers:
python3 examples/python/client.py --name alice
python3 examples/python/client.py --name bob
# or serve examples/javascript and open two tabs
```

Details: [MULTIPLAYER.md](MULTIPLAYER.md), [examples/README.md](examples/README.md).

## Non-goals

This is an experiment, not a commercial engine. Do **not** introduce:

- a universal game engine or shared runtime
- ECS unless an individual engine already uses it naturally
- matchmaking clouds, accounts, databases, or heavy netcode (rollback meshes, etc.)
- elaborate asset pipelines or unnecessary dependencies

A **tiny** shared WebSocket backend (see `backend/`) is intentional and kept minimal.

Prefer: **simple specification + simple simulation + simple adapters + simple tests** (+ one small server for online play).

## Status

| Phase | Status |
| --- | --- |
| Phase 0 — Architecture & documentation | **Done** |
| Phase 1 — Canonical Pong specification | **Done** |
| Phase 2 — Reference simulation + tests | **Done** (`reference/pong`, 14/14 tests) |
| Phase 2b — Cross-platform multiplayer backend | **Done** (`backend/`, `examples/`) |
| Phase 3+ — Full engine ports & tooling | See [ROADMAP.md](ROADMAP.md) |
