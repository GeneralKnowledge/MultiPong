extends SceneTree
## Headless runner: a few AI_SPEC smoke checks + one physics tick.
## Full JSON suite remains in reference/{pong,js,rust}; this guards the GDScript port.


func _init() -> void:
	var failed := 0
	failed += _check(
		"AI_IGNORES_MENU",
		func() -> bool:
			var s := PongSim.boot_state()
			return PongSim.ai_held(s, 2).is_empty()
	)
	failed += _check(
		"AI_TRACKS_BALL_P2",
		func() -> bool:
			var s := PongSim.boot_state()
			s["mode"] = "PLAYING"
			s["ball"] = {"x": 500.0, "y": 120.0, "vx": 300.0, "vy": 0.0, "active": true}
			var held: Array = PongSim.ai_held(s, 2)
			return held.size() == 1 and held[0] == "P2_UP"
	)
	failed += _check(
		"AI_DEADZONE_IDLE",
		func() -> bool:
			var s := PongSim.boot_state()
			s["mode"] = "PLAYING"
			s["ball"] = {"x": 500.0, "y": 305.0, "vx": 300.0, "vy": 0.0, "active": true}
			return PongSim.ai_held(s, 2).is_empty()
	)
	failed += _check(
		"AI_RETURNS_CENTER",
		func() -> bool:
			var s := PongSim.boot_state()
			s["mode"] = "PLAYING"
			s["ball"] = {"x": 500.0, "y": 500.0, "vx": -300.0, "vy": 0.0, "active": true}
			s["player2"]["y"] = 520.0
			var held: Array = PongSim.ai_held(s, 2)
			return held.size() == 1 and held[0] == "P2_UP"
	)
	failed += _check(
		"BALL_MOVES_HORIZONTAL",
		func() -> bool:
			var s := PongSim.boot_state()
			s["mode"] = "PLAYING"
			s["ball"] = {"x": 400.0, "y": 300.0, "vx": 300.0, "vy": 0.0, "active": true}
			for _i in 60:
				PongSim.step(s, [], [])
			return absf(float(s["ball"]["x"]) - 700.0) <= 1e-4 and absf(float(s["ball"]["y"]) - 300.0) <= 1e-4
	)
	failed += _check(
		"MENU_CONFIRM_STARTS",
		func() -> bool:
			var s := PongSim.boot_state()
			PongSim.step(s, [], ["CONFIRM"])
			return str(s["mode"]) == "PLAYING" and bool(s["ball"]["active"])
	)

	var total := 6
	var passed := total - failed
	print("%d/%d passed" % [passed, total])
	quit(1 if failed > 0 else 0)


func _check(id: String, fn: Callable) -> int:
	var ok: bool = fn.call()
	print("%s  %s" % ["PASS" if ok else "FAIL", id])
	return 0 if ok else 1
