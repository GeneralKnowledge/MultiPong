"""Canonical Pong simulation (engine-independent)."""

from __future__ import annotations

import math
from copy import deepcopy
from typing import Any

from . import constants as C

MODE_MENU = "MENU"
MODE_PLAYING = "PLAYING"
MODE_POINT_SCORED = "POINT_SCORED"
MODE_PAUSED = "PAUSED"
MODE_GAME_OVER = "GAME_OVER"

CANONICAL_HELD = {"P1_UP", "P1_DOWN", "P2_UP", "P2_DOWN"}
CANONICAL_EDGE = {"CONFIRM", "PAUSE", "RESTART"}


def boot_state() -> dict[str, Any]:
    return {
        "mode": MODE_MENU,
        "tick": 0,
        "elapsed_time": 0.0,
        "point_pause_remaining": 0.0,
        "mode_before_pause": None,
        "ball": {
            "x": C.PLAYFIELD_WIDTH / 2.0,
            "y": C.PLAYFIELD_HEIGHT / 2.0,
            "vx": 0.0,
            "vy": 0.0,
            "active": False,
        },
        "player1": {"y": C.PLAYFIELD_HEIGHT / 2.0, "score": 0},
        "player2": {"y": C.PLAYFIELD_HEIGHT / 2.0, "score": 0},
        "serving_player": 1,
        "winner": 0,
    }


def deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    out = deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = deep_merge(out[key], value)
        else:
            out[key] = deepcopy(value)
    return out


def clamp(value: float, lo: float, hi: float) -> float:
    return lo if value < lo else hi if value > hi else value


def reset_ball_for_serve(state: dict[str, Any], serving_player: int) -> None:
    ball = state["ball"]
    ball["x"] = C.PLAYFIELD_WIDTH / 2.0
    ball["y"] = C.PLAYFIELD_HEIGHT / 2.0
    ball["active"] = False
    speed = C.BALL_SPEED_INITIAL
    if serving_player == 1:
        ball["vx"] = speed
        ball["vy"] = 0.0
    else:
        ball["vx"] = -speed
        ball["vy"] = 0.0
    state["serving_player"] = serving_player


def start_match(state: dict[str, Any]) -> list[str]:
    state["player1"]["score"] = 0
    state["player2"]["score"] = 0
    state["player1"]["y"] = C.PLAYFIELD_HEIGHT / 2.0
    state["player2"]["y"] = C.PLAYFIELD_HEIGHT / 2.0
    state["winner"] = 0
    state["tick"] = 0
    state["elapsed_time"] = 0.0
    state["point_pause_remaining"] = 0.0
    state["mode_before_pause"] = None
    reset_ball_for_serve(state, 1)
    state["ball"]["active"] = True
    state["mode"] = MODE_PLAYING
    return ["ui_confirm"]


def full_reset(state: dict[str, Any]) -> None:
    state.clear()
    state.update(boot_state())


def _move_paddles(state: dict[str, Any], held: set[str]) -> None:
    dy1 = 0.0
    if "P1_UP" in held:
        dy1 -= C.PADDLE_SPEED * C.DT
    if "P1_DOWN" in held:
        dy1 += C.PADDLE_SPEED * C.DT
    state["player1"]["y"] = clamp(state["player1"]["y"] + dy1, C.PADDLE_Y_MIN, C.PADDLE_Y_MAX)

    dy2 = 0.0
    if "P2_UP" in held:
        dy2 -= C.PADDLE_SPEED * C.DT
    if "P2_DOWN" in held:
        dy2 += C.PADDLE_SPEED * C.DT
    state["player2"]["y"] = clamp(state["player2"]["y"] + dy2, C.PADDLE_Y_MIN, C.PADDLE_Y_MAX)


def _wall_collisions(state: dict[str, Any], events: list[str]) -> None:
    ball = state["ball"]
    if ball["y"] - C.BALL_RADIUS < 0:
        ball["y"] = C.BALL_RADIUS
        ball["vy"] = abs(ball["vy"])
        events.append("wall_hit")
    if ball["y"] + C.BALL_RADIUS > C.PLAYFIELD_HEIGHT:
        ball["y"] = C.PLAYFIELD_HEIGHT - C.BALL_RADIUS
        ball["vy"] = -abs(ball["vy"])
        events.append("wall_hit")


def _paddle_overlap(ball: dict[str, Any], paddle_x: float, paddle_y: float) -> bool:
    left = paddle_x - C.PADDLE_WIDTH / 2.0
    right = paddle_x + C.PADDLE_WIDTH / 2.0
    top = paddle_y - C.PADDLE_HEIGHT / 2.0
    bottom = paddle_y + C.PADDLE_HEIGHT / 2.0
    closest_x = clamp(ball["x"], left, right)
    closest_y = clamp(ball["y"], top, bottom)
    dx = ball["x"] - closest_x
    dy = ball["y"] - closest_y
    return (dx * dx + dy * dy) <= (C.BALL_RADIUS * C.BALL_RADIUS)


def _paddle_hit(state: dict[str, Any], which: int, events: list[str]) -> None:
    ball = state["ball"]
    if which == 1:
        if ball["vx"] >= 0:
            return
        paddle_x = C.PADDLE_P1_X
        paddle_y = state["player1"]["y"]
        direction = 1.0
    else:
        if ball["vx"] <= 0:
            return
        paddle_x = C.PADDLE_P2_X
        paddle_y = state["player2"]["y"]
        direction = -1.0

    if not _paddle_overlap(ball, paddle_x, paddle_y):
        return

    events.append("paddle_hit")
    offset = (ball["y"] - paddle_y) / (C.PADDLE_HEIGHT / 2.0)
    offset = clamp(offset, -1.0, 1.0)
    old_speed = math.sqrt(ball["vx"] * ball["vx"] + ball["vy"] * ball["vy"])
    new_speed = min(old_speed + C.BALL_SPEED_INCREMENT, C.BALL_SPEED_MAX)
    angle_rad = offset * C.MAX_BOUNCE_ANGLE_DEG * math.pi / 180.0
    ball["vx"] = new_speed * math.cos(angle_rad) * direction
    ball["vy"] = new_speed * math.sin(angle_rad)
    if which == 1:
        ball["x"] = paddle_x + C.PADDLE_WIDTH / 2.0 + C.BALL_RADIUS + C.SEPARATION_EPSILON
    else:
        ball["x"] = paddle_x - C.PADDLE_WIDTH / 2.0 - C.BALL_RADIUS - C.SEPARATION_EPSILON


def _handle_point_scored(state: dict[str, Any], scored_by: int, events: list[str]) -> None:
    if state["player1"]["score"] >= C.SCORE_TO_WIN or state["player2"]["score"] >= C.SCORE_TO_WIN:
        state["mode"] = MODE_GAME_OVER
        state["winner"] = 1 if state["player1"]["score"] >= C.SCORE_TO_WIN else 2
        state["ball"]["active"] = False
        events.append("game_over")
        return
    state["mode"] = MODE_POINT_SCORED
    state["point_pause_remaining"] = C.POINT_PAUSE_DURATION
    serving = 2 if scored_by == 1 else 1
    reset_ball_for_serve(state, serving)


def _check_scoring(state: dict[str, Any], events: list[str]) -> None:
    ball = state["ball"]
    if ball["x"] + C.BALL_RADIUS < 0:
        state["player2"]["score"] += 1
        events.append("score")
        _handle_point_scored(state, 2, events)
        return
    if ball["x"] - C.BALL_RADIUS > C.PLAYFIELD_WIDTH:
        state["player1"]["score"] += 1
        events.append("score")
        _handle_point_scored(state, 1, events)


def _playing_physics(state: dict[str, Any], held: set[str], events: list[str]) -> None:
    _move_paddles(state, held)
    ball = state["ball"]
    if ball["active"]:
        ball["x"] += ball["vx"] * C.DT
        ball["y"] += ball["vy"] * C.DT
        _wall_collisions(state, events)
        _paddle_hit(state, 1, events)
        _paddle_hit(state, 2, events)
        _check_scoring(state, events)

    if state["mode"] in (MODE_PLAYING, MODE_POINT_SCORED):
        state["tick"] += 1
        state["elapsed_time"] = state["tick"] * C.DT
    # GAME_OVER from scoring: do not increment tick


def step(state: dict[str, Any], held: list[str] | set[str] | None = None, pressed: list[str] | set[str] | None = None) -> list[str]:
    """Advance one fixed tick. Mutates state. Returns events."""
    held_set = {a for a in (held or []) if a in CANONICAL_HELD}
    pressed_set = {a for a in (pressed or []) if a in CANONICAL_EDGE}
    events: list[str] = []
    mode = state["mode"]

    if mode == MODE_MENU:
        if "RESTART" in pressed_set:
            full_reset(state)
            return events
        if "CONFIRM" in pressed_set:
            events.extend(start_match(state))
        return events

    if mode == MODE_PLAYING:
        if "RESTART" in pressed_set:
            full_reset(state)
            return events
        if "PAUSE" in pressed_set:
            state["mode_before_pause"] = MODE_PLAYING
            state["mode"] = MODE_PAUSED
            return events
        _playing_physics(state, held_set, events)
        return events

    if mode == MODE_POINT_SCORED:
        if "RESTART" in pressed_set:
            full_reset(state)
            return events
        if "PAUSE" in pressed_set:
            state["mode_before_pause"] = MODE_POINT_SCORED
            state["mode"] = MODE_PAUSED
            return events
        _move_paddles(state, held_set)
        state["point_pause_remaining"] -= C.DT
        if state["point_pause_remaining"] <= 0:
            state["point_pause_remaining"] = 0.0
            state["mode"] = MODE_PLAYING
            state["ball"]["active"] = True
        state["tick"] += 1
        state["elapsed_time"] = state["tick"] * C.DT
        return events

    if mode == MODE_PAUSED:
        if "RESTART" in pressed_set:
            full_reset(state)
            return events
        if "PAUSE" in pressed_set:
            resume = state.get("mode_before_pause") or MODE_PLAYING
            state["mode"] = resume
            state["mode_before_pause"] = None
        return events

    if mode == MODE_GAME_OVER:
        if "CONFIRM" in pressed_set:
            events.append("ui_confirm")
            full_reset(state)
            return events
        if "RESTART" in pressed_set:
            full_reset(state)
        return events

    return events


def state_to_jsonable(state: dict[str, Any]) -> dict[str, Any]:
    return deepcopy(state)
