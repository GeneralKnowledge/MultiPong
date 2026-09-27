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

This phase produces the **blueprint only**. No playable implementations yet.

| Document | Purpose |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Simulation layers, units, determinism, state, input, rendering |
| [GAME_SPEC.md](GAME_SPEC.md) | Spec format + index of games |
| [specs/pong/GAME_SPEC.md](specs/pong/GAME_SPEC.md) | Complete canonical Pong specification |
| [TESTING.md](TESTING.md) | Cross-engine tests, replays, comparison goals |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Rules, faithfulness criteria, per-engine template |
| [ROADMAP.md](ROADMAP.md) | Phased development plan |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to add a game or engine |

## Repository layout

```text
multi-engine-games/
├── README.md
├── ARCHITECTURE.md
├── GAME_SPEC.md
├── TESTING.md
├── IMPLEMENTATION_GUIDE.md
├── ROADMAP.md
├── CONTRIBUTING.md
│
├── specs/
│   └── pong/
│       ├── GAME_SPEC.md          # Human-readable canonical design
│       ├── constants.json        # Machine-readable constants
│       ├── state.schema.json     # Authoritative GameState schema
│       ├── actions.json          # Canonical input actions
│       ├── tests/                # Machine-readable behavioural tests
│       └── replays/              # Deterministic input sequences
│
├── assets/
│   └── pong/                     # Shared sprites, fonts, audio, reference art
│
├── reference/
│   └── pong/                     # Optional reference implementation (Phase 2)
│
├── implementations/
│   ├── pygame/
│   ├── godot/
│   ├── unity/
│   ├── unreal-cpp/
│   ├── unreal-blueprints/
│   ├── rpgmaker/
│   ├── gamemaker/
│   ├── love2d/
│   ├── phaser/
│   └── bevy/
│
└── tools/
    ├── test-runner/              # Future: run canonical tests per engine
    └── comparison/               # Future: aggregate cross-engine results
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

## Non-goals

This is an experiment, not a commercial engine. Do **not** introduce:

- a universal game engine or shared runtime
- ECS unless an individual engine already uses it naturally
- networking, multiplayer, cloud services, or databases
- elaborate asset pipelines or unnecessary dependencies

Prefer: **simple specification + simple simulation + simple adapters + simple tests**.

## Status

| Phase | Status |
| --- | --- |
| Phase 0 — Architecture & documentation | **In progress (this commit)** |
| Phase 1 — Canonical Pong specification | **Included** |
| Phase 2+ — Implementations & tooling | See [ROADMAP.md](ROADMAP.md) |
