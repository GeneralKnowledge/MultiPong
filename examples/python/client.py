#!/usr/bin/env python3
"""Polished Pygame client — online (authoritative server) or offline (local sim + AI)."""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from pathlib import Path
from typing import Any

try:
    import pygame
except ImportError as exc:
    raise SystemExit("pip install pygame") from exc

_ROOT = Path(__file__).resolve().parents[2]
_SPEC = _ROOT / "specs" / "pong" / "constants.json"
_REF = _ROOT / "reference" / "pong"
sys.path.insert(0, str(_REF))

with _SPEC.open(encoding="utf-8") as _f:
    C = json.load(_f)

W = int(C["playfield"]["width"])
H = int(C["playfield"]["height"])
BG = C["playfield"]["background_color"]
LINE = C["playfield"]["center_line_color"]
LINE_W = int(C["playfield"]["center_line_width"])
DASH = int(C["playfield"]["center_line_dash_length"])
GAP = int(C["playfield"]["center_line_gap"])
BALL_R = int(C["ball"]["radius"])
BALL_COLOR = C["ball"]["color"]
PAD_W = int(C["paddle"]["width"])
PAD_H = int(C["paddle"]["height"])
PAD_COLOR = C["paddle"]["color"]
P1_X = float(C["paddle"]["p1_x"])
P2_X = float(C["paddle"]["p2_x"])
SCORE_COLOR = C["scoring"]["score_color"]
SCORE_SIZE = int(C["scoring"]["score_font_size"])
SCORE_P1 = tuple(C["scoring"]["score_p1_center"])
SCORE_P2 = tuple(C["scoring"]["score_p2_center"])
UI = C["ui"]
TEXT = UI["text_color"]
YOU_OUTLINE = "#7FD0C5"
TICK_RATE = int(C["simulation"]["tick_rate"])
DT = 1.0 / TICK_RATE
MAX_STEPS = int(C["simulation"]["max_steps_per_frame"])
AI_SEAT = int(C["ai"]["default_ai_seat"])
HUMAN_SEAT = int(C["ai"]["default_human_seat"])


def hex_rgb(value: str) -> tuple[int, int, int]:
    v = value.lstrip("#")
    return int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="MultiPong Pygame client")
    p.add_argument(
        "--offline",
        action="store_true",
        help="Local sim + canonical AI (seat 2); no server",
    )
    p.add_argument("--url", default="ws://127.0.0.1:8765")
    p.add_argument("--room", default="demo")
    p.add_argument("--name", default="python")
    return p.parse_args()


def blit_centered(
    screen: pygame.Surface,
    font: pygame.font.Font,
    text: str,
    center: tuple[float, float],
    color: str,
) -> None:
    surf = font.render(text, True, hex_rgb(color))
    rect = surf.get_rect(center=(int(center[0]), int(center[1])))
    screen.blit(surf, rect)


def draw_playfield(screen: pygame.Surface) -> None:
    screen.fill(hex_rgb(BG))
    y = 0
    while y < H:
        pygame.draw.rect(screen, hex_rgb(LINE), (W // 2 - LINE_W // 2, y, LINE_W, DASH))
        y += DASH + GAP


def draw_paddle(screen: pygame.Surface, cx: float, cy: float, highlight: bool) -> None:
    rect = pygame.Rect(0, 0, PAD_W, PAD_H)
    rect.center = (int(cx), int(cy))
    pygame.draw.rect(screen, hex_rgb(PAD_COLOR), rect)
    if highlight:
        pygame.draw.rect(screen, hex_rgb(YOU_OUTLINE), rect, width=2)


def draw_game(
    screen: pygame.Surface,
    fonts: dict[str, pygame.font.Font],
    state: dict[str, Any] | None,
    you: int | None,
    status: str,
    seats: dict[str, Any] | None,
    offline: bool,
) -> None:
    draw_playfield(screen)

    if state:
        draw_paddle(screen, P1_X, state["player1"]["y"], you == 1)
        draw_paddle(screen, P2_X, state["player2"]["y"], you == 2)
        ball = state["ball"]
        pygame.draw.circle(
            screen, hex_rgb(BALL_COLOR), (int(ball["x"]), int(ball["y"])), BALL_R
        )

        blit_centered(
            screen, fonts["score"], str(state["player1"]["score"]), SCORE_P1, SCORE_COLOR
        )
        blit_centered(
            screen, fonts["score"], str(state["player2"]["score"]), SCORE_P2, SCORE_COLOR
        )

        mode = state["mode"]
        if mode == "MENU":
            blit_centered(screen, fonts["title"], UI["title"], tuple(UI["title_center"]), TEXT)
            if offline:
                waiting = UI["menu_subtitle"]
            else:
                waiting = (
                    "Waiting for opponent…"
                    if (seats and seats.get("players", 0) < 2)
                    else UI["menu_subtitle"]
                )
            blit_centered(screen, fonts["sub"], waiting, tuple(UI["subtitle_center"]), TEXT)
        elif mode == "PAUSED":
            blit_centered(screen, fonts["title"], UI["paused_text"], (W / 2, H / 2), TEXT)
        elif mode == "GAME_OVER":
            msg = UI["game_over_p1"] if state["winner"] == 1 else UI["game_over_p2"]
            blit_centered(screen, fonts["title"], msg, (W / 2, H / 2 - 24), TEXT)
            blit_centered(
                screen, fonts["sub"], UI["game_over_hint"], (W / 2, H / 2 + 28), TEXT
            )
        elif mode == "POINT_SCORED":
            blit_centered(screen, fonts["sub"], "Point!", (W / 2, H / 2), TEXT)

    seat = f"P{you}" if you else "—"
    mode_label = "offline vs AI" if offline else status
    line = (
        f"{mode_label}   seat {seat}   "
        "W/S or ↑/↓ move · Enter confirm · P pause · R restart"
    )
    screen.blit(fonts["hud"].render(line, True, hex_rgb("#8B95A8")), (12, H - 22))


def poll_keys() -> tuple[set[str], list[str], bool]:
    """Return (held seat-relative, pressed edges, quit)."""
    pressed: list[str] = []
    quit_requested = False
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            quit_requested = True
        elif event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                pressed.append("CONFIRM")
            elif event.key in (pygame.K_p, pygame.K_ESCAPE):
                pressed.append("PAUSE")
            elif event.key == pygame.K_r:
                pressed.append("RESTART")

    keys = pygame.key.get_pressed()
    held: set[str] = set()
    if keys[pygame.K_w] or keys[pygame.K_UP]:
        held.add("UP")
    if keys[pygame.K_s] or keys[pygame.K_DOWN]:
        held.add("DOWN")
    return held, pressed, quit_requested


def make_fonts() -> dict[str, pygame.font.Font]:
    return {
        "score": pygame.font.SysFont("dejavusansmono", SCORE_SIZE),
        "title": pygame.font.SysFont("dejavusansmono", int(UI["title_font_size"])),
        "sub": pygame.font.SysFont("dejavusansmono", int(UI["subtitle_font_size"])),
        "hud": pygame.font.SysFont("dejavusansmono", 14),
    }


def run_offline() -> None:
    from pong_sim import ai_held, boot_state, step  # noqa: PLC0415

    pygame.init()
    pygame.display.set_caption("MultiPong — offline vs AI")
    screen = pygame.display.set_mode((W, H))
    fonts = make_fonts()
    state = boot_state()
    you = HUMAN_SEAT
    accumulator = 0.0
    prev = time.perf_counter()
    running = True

    while running:
        now = time.perf_counter()
        frame_dt = min(now - prev, float(C["simulation"]["max_frame_time"]))
        prev = now
        accumulator += frame_dt

        held_rel, pressed, quit_requested = poll_keys()
        if quit_requested:
            running = False

        steps = 0
        while accumulator >= DT and steps < MAX_STEPS:
            human_held: list[str] = []
            if "UP" in held_rel:
                human_held.append("P1_UP")
            if "DOWN" in held_rel:
                human_held.append("P1_DOWN")
            held = sorted(set(human_held) | set(ai_held(state, AI_SEAT)))
            edge = pressed if steps == 0 else []
            pressed = []
            step(state, held, edge)
            accumulator -= DT
            steps += 1

        draw_game(screen, fonts, state, you, "Offline vs AI", None, offline=True)
        pygame.display.flip()
        # Cap display loop lightly; sim is accumulator-driven
        time.sleep(max(0.0, 1.0 / 120.0 - (time.perf_counter() - now)))

    pygame.quit()


async def run_online(args: argparse.Namespace) -> None:
    try:
        import websockets
        from websockets.exceptions import WebSocketException
    except ImportError as exc:
        raise SystemExit("pip install websockets") from exc

    pygame.init()
    pygame.display.set_caption(f"MultiPong — {args.name}")
    screen = pygame.display.set_mode((W, H))
    fonts = make_fonts()

    state: dict[str, Any] | None = None
    you: int | None = None
    seats: dict[str, Any] | None = None
    status = "Connecting…"
    running = True

    try:
        async with websockets.connect(args.url) as ws:
            await ws.send(
                json.dumps({"type": "join", "room": args.room, "name": args.name})
            )
            status = f"Connected · room {args.room}"

            async def reader() -> None:
                nonlocal state, you, seats, status
                async for raw in ws:
                    msg = json.loads(raw)
                    mtype = msg.get("type")
                    if mtype == "welcome":
                        you = int(msg["player"])
                        status = f"Connected · room {msg['room']} · you are P{you}"
                    elif mtype == "state":
                        state = msg["state"]
                        if msg.get("you"):
                            you = int(msg["you"])
                    elif mtype == "room":
                        seats = msg
                        n = int(msg.get("players", 0))
                        if n < 2:
                            status = f"Connected · waiting for opponent ({n}/2)"
                        else:
                            status = f"Connected · room {msg['room']} · 2/2"
                    elif mtype == "error":
                        status = f"Error: {msg.get('message')}"
                        print("ERROR:", msg.get("message"), file=sys.stderr)

            read_task = asyncio.create_task(reader())
            try:
                while running:
                    held, pressed, quit_requested = poll_keys()
                    if quit_requested:
                        running = False

                    await ws.send(
                        json.dumps(
                            {"type": "input", "held": sorted(held), "pressed": pressed}
                        )
                    )
                    draw_game(screen, fonts, state, you, status, seats, offline=False)
                    pygame.display.flip()
                    await asyncio.sleep(1 / 60)
            finally:
                read_task.cancel()
                try:
                    await read_task
                except asyncio.CancelledError:
                    pass
    except (OSError, WebSocketException) as exc:
        status = f"Connection failed: {exc}"
        print(status, file=sys.stderr)
        end = asyncio.get_event_loop().time() + 2.5
        while asyncio.get_event_loop().time() < end:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    end = 0
            draw_game(screen, fonts, None, None, status, None, offline=False)
            pygame.display.flip()
            await asyncio.sleep(1 / 30)
    finally:
        pygame.quit()


if __name__ == "__main__":
    args = parse_args()
    if args.offline:
        run_offline()
    else:
        asyncio.run(run_online(args))
