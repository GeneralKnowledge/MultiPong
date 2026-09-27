"""Canonical offline AI — specs/pong/AI_SPEC.md."""

from __future__ import annotations

from typing import Any

from . import constants as C

_ACTIVE_MODES = {"PLAYING", "POINT_SCORED"}


def ai_held(state: dict[str, Any], seat: int | None = None) -> list[str]:
    """Return held canonical actions for the AI seat this tick."""
    if seat is None:
        seat = C.AI_DEFAULT_AI_SEAT
    if state["mode"] not in _ACTIVE_MODES:
        return []

    paddle_y = state["player1"]["y"] if seat == 1 else state["player2"]["y"]
    ball = state["ball"]
    approaching = (seat == 1 and ball["vx"] < 0) or (seat == 2 and ball["vx"] > 0)

    if ball["active"] and approaching:
        target_y = ball["y"]
    else:
        target_y = C.PLAYFIELD_HEIGHT / 2.0

    delta = target_y - paddle_y
    up = "P1_UP" if seat == 1 else "P2_UP"
    down = "P1_DOWN" if seat == 1 else "P2_DOWN"
    if delta < -C.AI_DEADZONE:
        return [up]
    if delta > C.AI_DEADZONE:
        return [down]
    return []
