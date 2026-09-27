#!/usr/bin/env python3
"""Run canonical specs/pong/tests against the reference simulation."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from pong_sim import boot_state, deep_merge, step  # noqa: E402
from pong_sim import constants as C  # noqa: E402

TESTS_DIR = C.SPEC_DIR / "tests"


def expand_steps(steps: list[dict]) -> list[dict]:
    frames: list[dict] = []
    for step_spec in steps:
        repeat = int(step_spec.get("repeat", 1))
        frame = {
            "held": list(step_spec.get("held", [])),
            "pressed": list(step_spec.get("pressed", [])),
        }
        for _ in range(repeat):
            frames.append(frame)
    return frames


def get_path(obj: dict, path: list[str]):
    cur = obj
    for key in path:
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur


def collect_expect_paths(node: dict, prefix: list[str] | None = None) -> list[tuple[list[str], object]]:
    prefix = prefix or []
    out: list[tuple[list[str], object]] = []
    for key, value in node.items():
        path = prefix + [key]
        if isinstance(value, dict):
            out.extend(collect_expect_paths(value, path))
        else:
            out.append((path, value))
    return out


def values_close(expected, actual, pos_eps: float, vel_eps: float, path: list[str]) -> bool:
    if isinstance(expected, bool) or expected is None:
        return actual == expected
    if isinstance(expected, int) and not isinstance(expected, bool):
        if isinstance(actual, float) and actual.is_integer():
            return int(actual) == expected
        return actual == expected
    if isinstance(expected, float) or isinstance(actual, float):
        leaf = path[-1] if path else ""
        eps = vel_eps if leaf in {"vx", "vy"} else pos_eps
        if leaf in {"elapsed_time", "point_pause_remaining"}:
            eps = pos_eps
        try:
            return abs(float(actual) - float(expected)) <= eps
        except (TypeError, ValueError):
            return False
    return actual == expected


def run_test(path: Path) -> tuple[bool, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    state = deep_merge(boot_state(), data.get("initial", {}))
    events: list[str] = []
    for frame in expand_steps(data.get("steps", [])):
        events.extend(step(state, frame.get("held"), frame.get("pressed")))

    expect = data.get("expect", {})
    pos_eps = float(expect.get("position_epsilon", C.POSITION_EPSILON))
    vel_eps = float(expect.get("velocity_epsilon", C.VELOCITY_EPSILON))

    for path_keys, expected in collect_expect_paths(expect.get("state", {})):
        actual = get_path(state, path_keys)
        if not values_close(expected, actual, pos_eps, vel_eps, path_keys):
            return False, f"{'.'.join(path_keys)}: expected {expected!r}, got {actual!r}"

    expected_events = expect.get("events")
    if expected_events is not None:
        if expect.get("events_ordered"):
            # exact sequence
            if events != expected_events:
                return False, f"events: expected {expected_events!r}, got {events!r}"
        else:
            for name in expected_events:
                if name not in events:
                    return False, f"missing event {name!r}; got {events!r}"

    return True, "PASS"


def main() -> int:
    files = sorted(TESTS_DIR.glob("*.json"))
    if not files:
        print("No tests found", file=sys.stderr)
        return 1
    passed = 0
    failed = 0
    for path in files:
        ok, detail = run_test(path)
        status = "PASS" if ok else "FAIL"
        print(f"{status}  {path.stem}  {detail if not ok else ''}".rstrip())
        if ok:
            passed += 1
        else:
            failed += 1
    print(f"\n{passed}/{passed + failed} passed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
