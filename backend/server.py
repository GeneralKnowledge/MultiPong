#!/usr/bin/env python3
"""Tiny authoritative WebSocket server for cross-engine Pong multiplayer."""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from pathlib import Path
from typing import Any

# Allow importing reference simulation
ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "reference" / "pong"
sys.path.insert(0, str(REF))

from pong_sim import boot_state, step, state_to_jsonable  # noqa: E402
from pong_sim import constants as C  # noqa: E402

try:
    import websockets
    from websockets.asyncio.server import ServerConnection
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Install dependencies: pip install -r backend/requirements.txt") from exc

SEAT_ACTIONS = {"UP", "DOWN", "CONFIRM", "PAUSE", "RESTART"}
PROTOCOL_VERSION = 1


class Room:
    def __init__(self, name: str) -> None:
        self.name = name
        self.state = boot_state()
        self.seats: dict[int, dict[str, Any] | None] = {1: None, 2: None}
        # latest held per seat; pressed queued until tick
        self.held: dict[int, set[str]] = {1: set(), 2: set()}
        self.pressed: dict[int, set[str]] = {1: set(), 2: set()}

    def occupied(self) -> int:
        return sum(1 for s in self.seats.values() if s is not None)

    def assign(self, ws: ServerConnection, name: str) -> int | None:
        for seat in (1, 2):
            if self.seats[seat] is None:
                self.seats[seat] = {"ws": ws, "name": name}
                self.held[seat] = set()
                self.pressed[seat] = set()
                return seat
        return None

    def clear_seat(self, seat: int) -> None:
        self.seats[seat] = None
        self.held[seat] = set()
        self.pressed[seat] = set()

    def seat_of(self, ws: ServerConnection) -> int | None:
        for seat, info in self.seats.items():
            if info and info["ws"] is ws:
                return seat
        return None

    def room_message(self) -> dict[str, Any]:
        return {
            "type": "room",
            "room": self.name,
            "players": self.occupied(),
            "seats": {
                "1": self.seats[1]["name"] if self.seats[1] else None,
                "2": self.seats[2]["name"] if self.seats[2] else None,
            },
        }

    def build_input(self) -> tuple[list[str], list[str]]:
        held: list[str] = []
        pressed: list[str] = []
        if "UP" in self.held[1]:
            held.append("P1_UP")
        if "DOWN" in self.held[1]:
            held.append("P1_DOWN")
        if "UP" in self.held[2]:
            held.append("P2_UP")
        if "DOWN" in self.held[2]:
            held.append("P2_DOWN")
        for seat in (1, 2):
            for edge in ("CONFIRM", "PAUSE", "RESTART"):
                if edge in self.pressed[seat]:
                    pressed.append(edge)
            self.pressed[seat].clear()
        # unique preserve order
        pressed = list(dict.fromkeys(pressed))
        return held, pressed


class ServerApp:
    def __init__(self) -> None:
        self.rooms: dict[str, Room] = {}
        self.lock = asyncio.Lock()

    def get_room(self, name: str) -> Room:
        if name not in self.rooms:
            self.rooms[name] = Room(name)
        return self.rooms[name]

    async def broadcast(self, room: Room, message: dict[str, Any], exclude: ServerConnection | None = None) -> None:
        raw = json.dumps(message, separators=(",", ":"))
        for info in room.seats.values():
            if not info:
                continue
            ws = info["ws"]
            if exclude is not None and ws is exclude:
                continue
            try:
                await ws.send(raw)
            except Exception:
                pass

    async def send(self, ws: ServerConnection, message: dict[str, Any]) -> None:
        await ws.send(json.dumps(message, separators=(",", ":")))

    async def broadcast_state(self, room: Room) -> None:
        base = state_to_jsonable(room.state)
        for seat, info in room.seats.items():
            if not info:
                continue
            msg = {"type": "state", "room": room.name, "you": seat, "state": base}
            try:
                await info["ws"].send(json.dumps(msg, separators=(",", ":")))
            except Exception:
                pass

    async def handle(self, ws: ServerConnection) -> None:
        room: Room | None = None
        seat: int | None = None
        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    await self.send(ws, {"type": "error", "message": "invalid json"})
                    continue
                mtype = msg.get("type")
                if mtype == "ping":
                    await self.send(ws, {"type": "pong", "t": msg.get("t")})
                    continue

                async with self.lock:
                    if mtype == "join":
                        if seat is not None:
                            await self.send(ws, {"type": "error", "message": "already joined"})
                            continue
                        room_name = str(msg.get("room") or "demo")
                        name = str(msg.get("name") or "player")[:32]
                        room = self.get_room(room_name)
                        seat = room.assign(ws, name)
                        if seat is None:
                            await self.send(ws, {"type": "error", "message": "room full"})
                            room = None
                            continue
                        await self.send(
                            ws,
                            {
                                "type": "welcome",
                                "protocol": PROTOCOL_VERSION,
                                "player": seat,
                                "room": room_name,
                                "name": name,
                            },
                        )
                        await self.broadcast(room, room.room_message())
                        # Auto-start when both seated and still on MENU
                        if room.occupied() == 2 and room.state["mode"] == "MENU":
                            step(room.state, [], ["CONFIRM"])
                        await self.broadcast_state(room)
                        continue

                    if seat is None or room is None:
                        await self.send(ws, {"type": "error", "message": "join first"})
                        continue

                    if mtype == "input":
                        held = {a for a in msg.get("held", []) if a in SEAT_ACTIONS}
                        pressed = {a for a in msg.get("pressed", []) if a in SEAT_ACTIONS}
                        room.held[seat] = {a for a in held if a in {"UP", "DOWN"}}
                        room.pressed[seat].update(a for a in pressed if a in {"CONFIRM", "PAUSE", "RESTART"})
                        # also treat edge actions present in held as pressed once (for simple clients)
                        for edge in ("CONFIRM", "PAUSE", "RESTART"):
                            if edge in held:
                                room.pressed[seat].add(edge)
                        continue

                    await self.send(ws, {"type": "error", "message": f"unknown type {mtype}"})
        finally:
            async with self.lock:
                if room is not None and seat is not None:
                    room.clear_seat(seat)
                    # Return to menu so a reconnecting pair can restart cleanly
                    room.state = boot_state()
                    room.held = {1: set(), 2: set()}
                    room.pressed = {1: set(), 2: set()}
                    await self.broadcast(room, room.room_message())
                    await self.broadcast_state(room)

    async def tick_loop(self) -> None:
        next_t = time.perf_counter()
        while True:
            next_t += C.DT
            async with self.lock:
                for room in list(self.rooms.values()):
                    if room.occupied() == 0:
                        continue
                    held, pressed = room.build_input()
                    step(room.state, held, pressed)
                    await self.broadcast_state(room)
            delay = next_t - time.perf_counter()
            if delay > 0:
                await asyncio.sleep(delay)
            else:
                # behind schedule; reset baseline to avoid spiral
                next_t = time.perf_counter()
                await asyncio.sleep(0)


async def main() -> None:
    parser = argparse.ArgumentParser(description="MultiPong authoritative WebSocket server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    app = ServerApp()
    print(f"MultiPong server on ws://{args.host}:{args.port}  (rooms capacity 2)")
    async with websockets.serve(app.handle, args.host, args.port):
        await app.tick_loop()


if __name__ == "__main__":
    asyncio.run(main())
