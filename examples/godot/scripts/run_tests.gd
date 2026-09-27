extends SceneTree
## Headless runner for specs/pong/tests against the GDScript PongSim port.
## Usage: godot4 --headless --path examples/godot -s scripts/run_tests.gd


func _init() -> void:
	var tests_dir := _resolve_tests_dir()
	if tests_dir.is_empty():
		printerr("Could not find specs/pong/tests")
		quit(1)
		return

	var files: PackedStringArray = DirAccess.get_files_at(tests_dir)
	files.sort()
	var passed := 0
	var failed := 0
	for fname in files:
		if not fname.ends_with(".json"):
			continue
		var id := fname.get_basename()
		var path := tests_dir.path_join(fname)
		var err_msg := _run_test_file(path)
		if err_msg.is_empty():
			print("PASS  %s" % id)
			passed += 1
		else:
			print("FAIL  %s  %s" % [id, err_msg])
			failed += 1

	print("\n%d/%d passed" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


func _resolve_tests_dir() -> String:
	var here := ProjectSettings.globalize_path("res://").rstrip("/")
	var candidates := [
		here.path_join("../../specs/pong/tests"),
		here.path_join("../../../specs/pong/tests"),
	]
	for c in candidates:
		var abs_path: String = String(c).simplify_path()
		if DirAccess.dir_exists_absolute(abs_path):
			return abs_path
	return ""


func _run_test_file(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return "read failed"
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return "invalid JSON"
	var test: Dictionary = data

	var state := PongSim.boot_state()
	_deep_merge(state, test.get("initial", {}))

	if test.has("ai_seat") and typeof(test.get("expect", {})) == TYPE_DICTIONARY:
		var expect0: Dictionary = test["expect"]
		if expect0.has("ai_held"):
			var held: Array = PongSim.ai_held(state, int(test["ai_seat"]))
			var expected: Array = expect0["ai_held"]
			if not _same_held(held, expected):
				return "ai_held: expected %s, got %s" % [str(expected), str(held)]

	var use_ai: bool = test.has("ai_seat") and (test.get("steps", []) as Array).size() > 0
	var events: Array = []
	for frame in _expand_steps(test.get("steps", [])):
		var held: Array = (frame["held"] as Array).duplicate()
		if use_ai:
			for a in PongSim.ai_held(state, int(test["ai_seat"])):
				if a not in held:
					held.append(a)
		events.append_array(PongSim.step(state, held, frame["pressed"]))

	var expect: Dictionary = test.get("expect", {})
	var pos_eps := float(expect.get("position_epsilon", 1e-4))
	var vel_eps := float(expect.get("velocity_epsilon", 1e-4))

	if expect.has("state"):
		var bad := _check_partial(state, expect["state"], [], pos_eps, vel_eps)
		if not bad.is_empty():
			return bad

	if expect.has("events"):
		var want: Array = expect["events"]
		if expect.get("events_ordered", false):
			if str(events) != str(want):
				return "events: expected %s, got %s" % [str(want), str(events)]
		else:
			for name in want:
				if name not in events:
					return "missing event %s; got %s" % [str(name), str(events)]

	return ""


func _expand_steps(steps: Array) -> Array:
	var frames: Array = []
	for step_spec in steps:
		var d: Dictionary = step_spec
		var repeat := int(d.get("repeat", 1))
		var frame := {
			"held": d.get("held", []),
			"pressed": d.get("pressed", []),
		}
		for _i in repeat:
			frames.append(frame)
	return frames


func _same_held(a: Array, b: Array) -> bool:
	var aa := a.duplicate()
	var bb := b.duplicate()
	aa.sort()
	bb.sort()
	return str(aa) == str(bb)


func _deep_merge(base: Dictionary, overlay: Variant) -> void:
	if typeof(overlay) != TYPE_DICTIONARY:
		return
	for key in overlay.keys():
		var ov = overlay[key]
		if typeof(ov) == TYPE_DICTIONARY and base.has(key) and typeof(base[key]) == TYPE_DICTIONARY:
			_deep_merge(base[key], ov)
		else:
			base[key] = ov


func _check_partial(
	actual: Variant, expected: Variant, path: Array, pos_eps: float, vel_eps: float
) -> String:
	if typeof(expected) == TYPE_DICTIONARY:
		if typeof(actual) != TYPE_DICTIONARY:
			return "%s: expected object" % [".".join(path)]
		var exp_dict: Dictionary = expected
		var act_dict: Dictionary = actual
		for key in exp_dict.keys():
			var p: Array = path.duplicate()
			p.append(str(key))
			var bad: String = _check_partial(act_dict.get(key), exp_dict[key], p, pos_eps, vel_eps)
			if not bad.is_empty():
				return bad
		return ""

	var path_str: String = ".".join(path)
	var leaf: String = ""
	if path.size() > 0:
		leaf = str(path[path.size() - 1])

	if typeof(expected) == TYPE_BOOL or expected == null:
		if actual != expected:
			return "%s: expected %s, got %s" % [path_str, str(expected), str(actual)]
		return ""

	if typeof(expected) == TYPE_INT:
		var ai: int = 0
		if typeof(actual) == TYPE_FLOAT or typeof(actual) == TYPE_INT:
			ai = int(round(float(actual)))
		else:
			return "%s: expected %s, got %s" % [path_str, str(expected), str(actual)]
		if int(expected) != ai:
			if typeof(actual) == TYPE_FLOAT and absf(float(actual) - float(expected)) < 1e-9:
				return ""
			return "%s: expected %s, got %s" % [path_str, str(expected), str(actual)]
		return ""

	if typeof(expected) == TYPE_FLOAT or typeof(actual) == TYPE_FLOAT:
		var eps: float = pos_eps
		if leaf == "vx" or leaf == "vy":
			eps = vel_eps
		if leaf == "elapsed_time" or leaf == "point_pause_remaining":
			eps = pos_eps
		if absf(float(actual) - float(expected)) > eps:
			return "%s: expected %s, got %s" % [path_str, str(expected), str(actual)]
		return ""

	if str(actual) != str(expected):
		return "%s: expected %s, got %s" % [path_str, str(expected), str(actual)]
	return ""
