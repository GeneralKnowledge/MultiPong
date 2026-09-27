"""Pong simulation package — canonical Python reference."""

from .simulation import boot_state, deep_merge, step, state_to_jsonable, start_match
from .ai import ai_held
from . import constants

__all__ = [
    "boot_state",
    "deep_merge",
    "step",
    "state_to_jsonable",
    "start_match",
    "ai_held",
    "constants",
]
