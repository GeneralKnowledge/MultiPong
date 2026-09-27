"""Load Pong constants from specs/pong/constants.json."""

from __future__ import annotations

import json
from pathlib import Path

_SPEC_DIR = Path(__file__).resolve().parents[3] / "specs" / "pong"
_CONSTANTS_PATH = _SPEC_DIR / "constants.json"

with _CONSTANTS_PATH.open(encoding="utf-8") as f:
    RAW = json.load(f)

PLAYFIELD_WIDTH = float(RAW["playfield"]["width"])
PLAYFIELD_HEIGHT = float(RAW["playfield"]["height"])

TICK_RATE = int(RAW["simulation"]["tick_rate"])
DT = 1.0 / TICK_RATE

BALL_RADIUS = float(RAW["ball"]["radius"])
BALL_SPEED_INITIAL = float(RAW["ball"]["speed_initial"])
BALL_SPEED_MAX = float(RAW["ball"]["speed_max"])
BALL_SPEED_INCREMENT = float(RAW["ball"]["speed_increment"])
SEPARATION_EPSILON = float(RAW["ball"]["separation_epsilon"])

PADDLE_WIDTH = float(RAW["paddle"]["width"])
PADDLE_HEIGHT = float(RAW["paddle"]["height"])
PADDLE_SPEED = float(RAW["paddle"]["speed"])
PADDLE_P1_X = float(RAW["paddle"]["p1_x"])
PADDLE_P2_X = float(RAW["paddle"]["p2_x"])
MAX_BOUNCE_ANGLE_DEG = float(RAW["paddle"]["max_bounce_angle_deg"])

PADDLE_Y_MIN = PADDLE_HEIGHT / 2.0
PADDLE_Y_MAX = PLAYFIELD_HEIGHT - PADDLE_HEIGHT / 2.0

SCORE_TO_WIN = int(RAW["scoring"]["score_to_win"])
POINT_PAUSE_DURATION = float(RAW["scoring"]["point_pause_duration"])

POSITION_EPSILON = float(RAW["comparison"]["position_epsilon"])
VELOCITY_EPSILON = float(RAW["comparison"]["velocity_epsilon"])

SPEC_DIR = _SPEC_DIR
