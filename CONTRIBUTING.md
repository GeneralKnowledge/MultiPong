# Contributing

## Principles

1. Spec first — behaviour changes land in `specs/<game>/` before engines diverge.
2. Tests travel with rules — update `tests/` in the same change.
3. Keep it small — no frameworks, speculative abstraction, or alternate net protocols.
4. Document deviations in the engine README.

## Adding an engine implementation

1. Choose or create `implementations/<engine>/`.
2. Follow [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md).
3. Implement simulation + headless tests before polishing art.
4. Pass all tests under `specs/pong/tests/`.
5. Fill in the README sections (engine version, run instructions, mapping, differences).
6. Commit reports under `implementations/<engine>/reports/` when stable.

## Changing the Pong specification

1. Edit `GAME_SPEC.md` and `constants.json` together.
2. Bump `version` in `constants.json`.
3. Fix or add tests.
4. Note the change in this file’s spirit: announce breaking behaviour in the PR description.
5. Expect all implementations to update.

## Adding a new game

1. Create `specs/<newgame>/` using the section template in [GAME_SPEC.md](GAME_SPEC.md).
2. Add `assets/<newgame>/` placeholders.
3. Do not require all engines to port immediately.
4. Update [ROADMAP.md](ROADMAP.md) and the games table in `GAME_SPEC.md`.

## Code review checklist

- [ ] Simulation has no engine physics for authoritative motion
- [ ] Constants loaded from or duplicated exactly from `constants.json`
- [ ] Headless tests exist and pass
- [ ] README lists known differences
- [ ] No unrelated refactors

## Questions / ambiguity

If the spec is ambiguous, **open a discussion and tighten the spec** rather than inventing local behaviour. The whole point of this repo is shared decisions written down once.
