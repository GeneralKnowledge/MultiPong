#!/usr/bin/env python3
"""Minimal Python multiplayer client (stdio + optional pygame window)."""

from __future__ import annotations

import argparse
import asyncio
import json
import sys

try:
    import websockets
except ImportError as exc:
    raise SystemExit("pip install websockets") from exc

# Optional rendering
try:
    import pygame
except ImportError:
    pygame = None  # type: ignore


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="ws://127.0.0.1:8765")
    p.add_argument("--room", default="demo")
    p.add_argument("--name", default="python")
    p.add_argument("--headless", action="store_true", help="No pygame; print state ticks")
    return p.parse_args()


async def run(args: argparse.Namespace) -> None:
    use_pygame = pygame is not None and not args.headless
    if use_pygame:
        pygame.init()
        screen = pygame.display.set_mode((800, 600))
        pygame.display.set_caption("MultiPong Python client")
        clock = pygame.time.Clock()
        font = pygame.font.SysFont("monospace", 20)
    else:
        screen = clock = font = None
        print("Headless mode — printing state summaries. Keys unavailable without pygame.")

    state = None
    you = None
    held: set[str] = set()
    pressed: list[str] = []

    async with websockets.connect(args.url) as ws:
        await ws.send(json.dumps({"type": "join", "room": args.room, "name": args.name}))

        async def reader() -> None:
            nonlocal state, you
            async for raw in ws:
                msg = json.loads(raw)
                if msg.get("type") == "welcome":
                    you = msg.get("player")
                    print(f"Joined as player {you}")
                elif msg.get("type") == "state":
                    state = msg.get("state")
                    you = msg.get("you", you)
                elif msg.get("type") == "error":
                    print("ERROR:", msg.get("message"), file=sys.stderr)
                elif msg.get("type") == "room":
                    print("Room:", msg)

        read_task = asyncio.create_task(reader())
        try:
            while True:
                pressed = []
                if use_pygame:
                    assert pygame is not None and screen is not None and clock is not None and font is not None
                    for event in pygame.event.get():
                        if event.type == pygame.QUIT:
                            return
                        if event.type == pygame.KEYDOWN:
                            if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                                pressed.append("CONFIRM")
                            if event.key in (pygame.K_p, pygame.K_ESCAPE):
                                pressed.append("PAUSE")
                            if event.key == pygame.K_r:
                                pressed.append("RESTART")
                    keys = pygame.key.get_pressed()
                    held = set()
                    if keys[pygame.K_w] or keys[pygame.K_UP]:
                        held.add("UP")
                    if keys[pygame.K_s] or keys[pygame.K_DOWN]:
                        held.add("DOWN")

                    screen.fill((11, 14, 20))
                    if state:
                        # centre line
                        for y in range(0, 600, 28):
                            pygame.draw.rect(screen, (42, 51, 68), (398, y, 4, 16))
                        p1y = state["player1"]["y"]
                        p2y = state["player2"]["y"]
                        pygame.draw.rect(screen, (232, 238, 245), (40 - 6, p1y - 40, 12, 80))
                        pygame.draw.rect(screen, (232, 238, 245), (760 - 6, p2y - 40, 12, 80))
                        pygame.draw.circle(
                            screen,
                            (242, 245, 248),
                            (int(state["ball"]["x"]), int(state["ball"]["y"])),
                            8,
                        )
                        score = font.render(
                            f"{state['player1']['score']}  -  {state['player2']['score']}   "
                            f"[{state['mode']}] you=P{you}",
                            True,
                            (242, 245, 248),
                        )
                        screen.blit(score, (240, 20))
                    pygame.display.flip()
                    clock.tick(60)
                else:
                    if state and state.get("tick", 0) % 60 == 0:
                        print(
                            f"tick={state['tick']} mode={state['mode']} "
                            f"score={state['player1']['score']}-{state['player2']['score']} "
                            f"ball=({state['ball']['x']:.1f},{state['ball']['y']:.1f})"
                        )
                    await asyncio.sleep(1 / 60)

                await ws.send(json.dumps({"type": "input", "held": sorted(held), "pressed": pressed}))
        finally:
            read_task.cancel()


if __name__ == "__main__":
    asyncio.run(run(parse_args()))
