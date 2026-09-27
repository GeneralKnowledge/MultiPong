# Python (Pygame) — simple dual-mode Pong

Beginner-friendly example. Presentation from `specs/pong/constants.json`. Simulation from `reference/pong`.

| Mode | Flag | Opponent |
| --- | --- | --- |
| Online | (default) | Remote human via server |
| Offline | `--offline` | Canonical AI (seat 2) |

See also [../BEGINNER.md](../BEGINNER.md).

## Quick start (offline)

```bash
python3 -m pip install -r examples/python/requirements.txt
python3 examples/python/client.py --offline
```

Press **Enter** to start. You are the left paddle.

## Online

```bash
python3 backend/server.py          # terminal 1
python3 examples/python/client.py --name alice
python3 examples/python/client.py --name bob   # terminal 3
```

| Flag | Default |
| --- | --- |
| `--offline` | off |
| `--url` | `ws://127.0.0.1:8765` |
| `--room` | `demo` |
| `--name` | `python` |

## Controls

| Keys | Action |
| --- | --- |
| `W` / `↑` · `S` / `↓` | Move |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |

Your paddle is outlined in teal. Online matches start when the second player joins.
