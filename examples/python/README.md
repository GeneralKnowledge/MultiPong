# Python (Pygame) multiplayer client

Polished online client. Loads colours/sizes from `specs/pong/constants.json` and talks to the authoritative server.

## Setup

```bash
python3 -m pip install -r examples/python/requirements.txt
# server in another terminal:
python3 backend/server.py
```

## Run

```bash
python3 examples/python/client.py --name alice
# second player (JS or another Python):
python3 examples/python/client.py --name bob
```

| Flag | Default |
| --- | --- |
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

Your paddle is outlined in teal. Match auto-starts when the second player joins the room.
