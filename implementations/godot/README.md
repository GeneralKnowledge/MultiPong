# Pong — Godot

| Field | Value |
| --- | --- |
| Engine | Godot |
| Language | GDScript |
| Engine version | 4.7 |
| Spec | `specs/pong` v1.1.0 |
| Status | **Dual-mode client in `examples/godot/`** |

## Install & run

See [examples/godot/README.md](../../examples/godot/README.md).

```bash
godot4 --path examples/godot -- --offline
# or online:
godot4 --path examples/godot -- --online --name godot1
```

## Tests

GDScript smoke (AI + a few ticks):

```bash
godot4 --headless --path examples/godot -s scripts/run_tests.gd
```

Full canonical JSON suite: `tools/comparison/run_all_tests.sh` (Python / JS / Rust references).

## Spec mapping

| Canonical | Godot |
| --- | --- |
| GameState / `step` / `ai_held` | `examples/godot/scripts/pong_sim.gd` |
| Online | `WebSocketPeer` |
| Render | `Node2D._draw()` |
| Physics | **Not used** |

## Coordinate conversion

None — Godot 2D matches canonical Y-down.

## Known differences

- Font is the engine fallback font (IBM Plex Mono not bundled).
- Older sketch: `examples/gdscript/MultiPongClient.gd` (online-only helper). Prefer `examples/godot/`.

## Test results

GDScript smoke: **6/6**. Full suite: covered by reference languages.
