# Testing Strategy

Cross-engine behavioural testing is a primary goal of this project. Looking similar is not enough; implementations should produce matching **state transitions** for matching inputs.

---

## 1. Goals

| Goal | Meaning |
| --- | --- |
| Correctness | Each engine obeys `specs/<game>/GAME_SPEC.md` |
| Comparability | Same tests run against every engine |
| Determinism | Replays reproduce state sequences within tolerance |
| Headless | Tests do not require a window or GPU |

Long-term flow:

```text
canonical test / replay
        ↓
   Pygame / Godot / Unity / Unreal / …
        ↓
   state dumps + pass/fail
        ↓
   comparison tool aggregates
```

---

## 2. Test kinds

### 2.1 Unit / behavioural tests (required first)

JSON files under `specs/<game>/tests/`. Each test:

1. Loads an `initial` `GameState` (partial overlays on boot defaults).
2. Applies a sequence of `InputFrame`s (`steps`), one per simulation tick.
3. Compares the resulting state (and optionally events) to `expect`.

Schema: `specs/pong/test.schema.json`.

### 2.2 Replay tests (Phase 5+)

JSON files under `specs/<game>/replays/`. A replay lists input by tick. Engines step headlessly and may dump full state traces for diffing.

Schema: `specs/pong/replay.schema.json`.

### 2.3 Manual visual checklist (not automated)

Confirm colours, score placement, menu text, and audio cues. Deviations go in the engine README under “known differences.”

---

## 3. Test file format

Example:

```json
{
  "id": "BALL_MOVES_HORIZONTAL",
  "description": "Ball travels +300 px in 1 second.",
  "initial": {
    "mode": "PLAYING",
    "ball": { "x": 400, "y": 300, "vx": 300, "vy": 0, "active": true }
  },
  "steps": [
    { "held": [], "pressed": [], "repeat": 60 }
  ],
  "expect": {
    "state": {
      "ball": { "x": 700, "y": 300, "vx": 300, "vy": 0 }
    }
  }
}
```

### Comparison rules

1. Only fields present under `expect.state` are checked (deep partial match).
2. Integers/enums (`score`, `mode`, `tick`, `winner`, `serving_player`, `active`) MUST match **exactly**.
3. Floating fields use absolute epsilon:
   - default positions: `constants.comparison.position_epsilon` (`1e-4`)
   - default velocities: `constants.comparison.velocity_epsilon` (`1e-4`)
   - per-test overrides allowed via `expect.position_epsilon` / `expect.velocity_epsilon`
4. `expect.events`: each listed event name must appear at least once during the run unless `events_ordered` is true (then sequence must match as a subsequence or exact list — runners SHOULD treat as **multiset contains** for unordered, **exact sequence** for ordered).

### Filling initial state

Start from MENU boot defaults ([GAME_SPEC §13](specs/pong/GAME_SPEC.md)), then deep-merge `initial`.

---

## 4. Replay format

```json
{
  "id": "sample_serve_and_miss",
  "version": "1.0.0",
  "tick_rate": 60,
  "initial": { "...": "GameState" },
  "frames": [
    { "tick": 0, "held": ["P1_UP"], "pressed": [] },
    { "tick": 1, "held": ["P1_UP"], "pressed": [] },
    { "tick": 3, "held": [], "pressed": ["PAUSE"] }
  ]
}
```

Runner behaviour:

1. Load `initial`.
2. For `t` from 0 to `max_tick` (inclusive of last frame tick, or an explicit `duration_ticks` if added later):
   - Build `InputFrame` from the frame with `tick == t`, or empty if none.
   - `step(state, input, DT)`.
   - Optionally append serialized state to a trace file.

Sparse frames: ticks without entries mean empty `held`/`pressed`.

### Trace dump format (future)

JSON Lines, one object per tick after step:

```json
{"tick":1,"mode":"PLAYING","ball":{"x":405,"y":300,"vx":300,"vy":0,"active":true},"...":"..."}
```

Field names MUST match `state.schema.json`.

---

## 5. Per-engine test harness

Each implementation SHOULD provide:

| Entry | Purpose |
| --- | --- |
| Headless sim library / module | `step`, state serialize |
| Test runner script | Load all `specs/pong/tests/*.json`, run, exit non-zero on failure |
| Optional replay runner | Consume `replays/*.json`, write traces |

Suggested CLI shape (adapt to language):

```text
run_tests --spec ../../specs/pong --report reports/pong_tests.json
run_replay --replay ../../specs/pong/replays/foo.json --out traces/foo.jsonl
```

Report JSON (for future comparison tool):

```json
{
  "game": "pong",
  "engine": "pygame",
  "engine_version": "2.5.2",
  "spec_version": "1.0.0",
  "passed": 14,
  "failed": 0,
  "total": 14,
  "results": [
    { "id": "BALL_MOVES_HORIZONTAL", "status": "PASS", "detail": null }
  ]
}
```

---

## 6. Comparison system (design only — do not implement yet)

Target UX:

```text
compare pong

Pong Cross-Engine Comparison
Implementation       Tests       Status
-----------------------------------------------
Pygame               14/14       PASS
Godot                14/14       PASS
Unity                14/14       PASS
...
```

Architecture:

```text
tools/comparison/
  - reads implementations/*/reports/*.json
  - optionally diffs traces for a named replay
  - prints table + writes summary.md / summary.json
```

Rules:

- Missing report → `MISSING`
- Any failed test → `FAIL`
- All pass → `PASS`
- Trace diffs: fail if any float exceeds epsilon or any exact field mismatches

No shared runtime is required — only shared **file formats**.

---

## 7. What not to test (yet)

- Pixel-perfect framebuffer diffs
- Audio waveform identity
- Performance / FPS
- Packaging installers

---

## 8. Adding tests

1. Prefer small, single-behaviour tests.
2. Compute expected values from the spec by hand or via the reference implementation (once it exists).
3. Name IDs `SCREAMING_SNAKE_CASE`.
4. Update `specs/pong/tests/README.md`.
5. Never rely on engine physics to “probably” bounce.

---

## 9. Pong initial pack

See [specs/pong/tests/README.md](specs/pong/tests/README.md) for the current list (movement, walls, paddle, scoring, modes, pause).

## 10. Running tests today

| Runner | Command |
| --- | --- |
| Python | `python3 reference/pong/run_tests.py` |
| JavaScript | `node reference/js/run_tests.mjs` |
| Rust | `cd reference/rust && cargo run --release --bin run_tests` |
| All three | `./tools/comparison/run_all_tests.sh` |
