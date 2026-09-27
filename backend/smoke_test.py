#!/usr/bin/env python3
"""Two-client smoke test against the authoritative server."""

from __future__ import annotations

import asyncio
import json
import sys

import websockets


async def client(
    name: str,
    hold: list[str],
    ready: asyncio.Event,
    done: asyncio.Event,
    room: str,
) -> dict:
    last = {}
    async with websockets.connect("ws://127.0.0.1:8765") as ws:
        await ws.send(json.dumps({"type": "join", "room": room, "name": name}))
        ready.set()
        while not done.is_set():
            await ws.send(json.dumps({"type": "input", "held": hold, "pressed": []}))
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=0.05)
            except asyncio.TimeoutError:
                continue
            msg = json.loads(raw)
            if msg.get("type") == "state":
                last = msg
        return last


async def main() -> int:
    room = f"smoke-{int(asyncio.get_event_loop().time() * 1000) % 1_000_000}"
    done = asyncio.Event()
    r1 = asyncio.Event()
    r2 = asyncio.Event()
    t1 = asyncio.create_task(client("a", ["UP"], r1, done, room))
    await r1.wait()
    t2 = asyncio.create_task(client("b", ["DOWN"], r2, done, room))
    await r2.wait()
    await asyncio.sleep(2.0)
    done.set()
    msg1, msg2 = await asyncio.gather(t1, t2)
    if not msg1 or not msg2:
        print("FAIL: missing state", file=sys.stderr)
        return 1
    s1, s2 = msg1["state"], msg2["state"]
    print(
        f"P{msg1['you']} mode={s1['mode']} score={s1['player1']['score']}-{s1['player2']['score']} "
        f"p1y={s1['player1']['y']:.1f} p2y={s1['player2']['y']:.1f}"
    )
    print(
        f"P{msg2['you']} mode={s2['mode']} score={s2['player1']['score']}-{s2['player2']['score']} "
        f"p1y={s2['player1']['y']:.1f} p2y={s2['player2']['y']:.1f}"
    )
    if msg1["you"] == msg2["you"]:
        print("FAIL: both clients got same seat", file=sys.stderr)
        return 1
    if s1["mode"] not in {"PLAYING", "POINT_SCORED", "PAUSED"}:
        print("FAIL: expected match to have started", s1["mode"], file=sys.stderr)
        return 1
    if s1["mode"] != s2["mode"] or s1["tick"] != s2["tick"]:
        print("FAIL: clients saw divergent state", file=sys.stderr)
        return 1
    if not (s1["player1"]["y"] < 300 and s1["player2"]["y"] > 300):
        print("FAIL: paddle positions not reflecting input", file=sys.stderr)
        return 1
    print("PASS smoke test")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
