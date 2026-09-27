"""Pong simulation package — canonical Python reference."""

from .simulation import boot_state, deep_merge, step, state_to_jsonable, start_match
from . import constants

__all__ = [
    "boot_state",
    "deep_merge",
    "step",
    "state_to_jsonable",
    "start_match",
    "constants",
]
