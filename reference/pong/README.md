# Reference implementation — Pong

Canonical **Python** simulation used for:

- Offline behavioural tests (`run_tests.py`)
- The authoritative multiplayer server (`backend/server.py`)

## Layout

```text
reference/pong/
├── pong_sim/
│   ├── constants.py      # loads specs/pong/constants.json
│   └── simulation.py     # boot_state, step, …
└── run_tests.py
```

## Run tests

```bash
python3 reference/pong/run_tests.py
```

The **spec** remains normative. If tests and markdown disagree on numbers, fix the loser after checking `constants.json`.
