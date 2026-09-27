# Python (Pygame) client

Dual-mode polished client. Presentation from `specs/pong/constants.json`.

| Mode | Flag | Who simulates | Opponent |
| --- | --- | --- | --- |
| Online | (default) | Authoritative server | Remote human |
| Offline | `--offline` | Local `reference/pong` sim | Canonical `simple_track` AI (seat 2) |

Offline AI: [specs/pong/AI_SPEC.md](../../specs/pong/AI_SPEC.md).

## Setup

```bash
python3 -m pip install -r examples/python/requirements.txt
```

## Offline (vs AI)

```bash
python3 examples/python/client.py --offline
```

You are always seat 1 (left). Enter starts the match.

## Online

```bash
# server in another terminal:
python3 backend/server.py

python3 examples/python/client.py --name alice
# second player:
python3 examples/python/client.py --name bob
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
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `Enter` / `Space` | Confirm |
| `P` / `Esc` | Pause |
| `R` | Restart |

Your paddle is outlined in teal. Online matches auto-start when the second player joins.
