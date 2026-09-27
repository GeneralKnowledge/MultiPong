# Shared assets — Pong

All Pong implementations SHOULD use these files (or exact copies imported into the engine).

```text
assets/pong/
├── sprites/          # Optional paddle/ball sprites; rectangles/circles are valid fallbacks
├── fonts/            # Prefer PressStart2P-Regular.ttf (add when licensing allows)
├── audio/            # WAV masters: paddle_hit, wall_hit, score, game_over, ui_confirm
└── reference/        # Screenshots / layout guides for visual QA
```

## Policy

| Asset | Shared? | Notes |
| --- | --- | --- |
| Colours / sizes | Yes (via constants) | Collision bounds follow constants, not art pixel size if they disagree — **fix art** |
| Font file | Yes when present | Document fallback in engine README |
| Audio WAV | Yes | Engines may transcode locally |
| Engine import settings | No | Per-engine |

## Deliberate simplicity

Assets stay minimal so the experiment focuses on engines, not art production. Solid-colour geometry is an acceptable MVP until sprites/audio are added.

## Status

Placeholder directories only in Phase 0/1. Binary assets may be added in Phase 2 without changing gameplay constants.
