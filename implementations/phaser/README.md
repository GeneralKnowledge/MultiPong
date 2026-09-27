# Pong — Phaser

| Field | Value |
| --- | --- |
| Engine | Phaser |
| Language | JavaScript (ES modules) |
| Engine version | 3.87 |
| Spec | `specs/pong` v1.1.0 |
| Status | **Dual-mode client in `examples/phaser/`** |

## Install & run

See [examples/phaser/README.md](../../examples/phaser/README.md).

Serve the **repo root**, then open `/examples/phaser/?offline=1` or connect online against `backend/server.py`.

## Tests

Canonical headless tests run via the shared JS reference:

```bash
node reference/js/run_tests.mjs
```

The Phaser client reuses `reference/js/pong_sim.js` for offline play (Exact sim + AI).

## Spec mapping

| Canonical | Phaser |
| --- | --- |
| GameState | Object from sim / WebSocket |
| `step()` / `aiHeld()` | `reference/js/pong_sim.js` |
| InputFrame | Seat-relative online; `P1_*` ∪ AI offline |
| Render | Phaser GameObjects only |

## Coordinate conversion

None — Phaser matches canonical Y-down.

## Known differences

- Ball is a Phaser circle; paddles are rectangles (no engine physics).
- Phaser loaded from CDN in the example page.

## Test results

Sim/AI: covered by `reference/js` (18/18). Client: manual dual-mode checklist.
