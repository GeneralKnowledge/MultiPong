# Game Specification Format

This document defines how canonical games are specified and indexes the games in this repository.

The authoritative design for each game lives under `specs/<game>/`. Root-level files describe **methodology**; per-game files describe **that game**.

---

## 1. Goals of a GAME_SPEC

A `GAME_SPEC.md` must be precise enough that **two developers**, working independently in different engines, produce substantially identical behaviour without further design negotiations.

It must be:

- **Human-readable** — prose and tables a person can implement from
- **Normative** — words like MUST / SHOULD follow RFC 2119 style where it matters
- **Complete for simulation** — every rule needed to step the game
- **Accompanied by machine-readable files** — constants, schemas, tests

It must not:

- prescribe Unity prefabs, Godot node trees, or Unreal Actors
- leave collision or scoring “up to the physics engine”
- mix binding keys into the simulation rules (bindings are documented separately)

---

## 2. Standard sections

Every `specs/<game>/GAME_SPEC.md` SHOULD include:

| Section | Contents |
| --- | --- |
| Overview | One-paragraph game description; non-goals |
| Playfield | Size, coordinate system reminder, colours |
| Constants | Table mirroring `constants.json` |
| Entities | Ball, paddles, etc.: dimensions, positions, motion |
| Simulation | Timestep, update order |
| Input | Canonical actions + default bindings |
| Collision | Exact maths |
| Scoring / win | Conditions and numbers |
| Game modes | State machine with transitions |
| Serving / reset | Exact post-point and post-match state |
| Presentation | What to draw; UI strings |
| Audio | Event → sound mapping |
| Determinism notes | RNG (if any), tolerances |
| Out of scope | Explicit non-features |

---

## 3. Companion files

| File | Role |
| --- | --- |
| `constants.json` | All numeric/string constants; **source of truth for numbers** |
| `state.schema.json` | JSON Schema for authoritative `GameState` dumps |
| `actions.json` | Canonical action names and default bindings |
| `tests/*.json` | Behavioural tests (see [TESTING.md](TESTING.md)) |
| `replays/*.json` | Input sequences for replay testing |

If `GAME_SPEC.md` and `constants.json` disagree, **`constants.json` wins for numbers**; fix the markdown in the same change.

---

## 4. Games

| Game | Spec | Status |
| --- | --- | --- |
| Pong | [specs/pong/GAME_SPEC.md](specs/pong/GAME_SPEC.md) | Canonical spec complete; implementations not started |

---

## 5. Adding a new game

1. Create `specs/<game>/` with the files above.
2. Keep the first version **small** — enough to exercise state, input, collision, timing, UI, audio.
3. Add shared assets under `assets/<game>/`.
4. Do not implement engines until the spec and a minimal test pack exist.
5. Update this index and [ROADMAP.md](ROADMAP.md).

See [CONTRIBUTING.md](CONTRIBUTING.md).
