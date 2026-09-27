extends RefCounted
## Canonical Pong simulation (GDScript port of reference/*).
## No Godot physics — all motion via step(). See specs/pong/GAME_SPEC.md + AI_SPEC.md.
class_name PongSim

const PLAYFIELD_WIDTH := 800.0
const PLAYFIELD_HEIGHT := 600.0
const TICK_RATE := 60
const DT := 1.0 / 60.0
const BALL_RADIUS := 8.0
const BALL_SPEED_INITIAL := 300.0
const BALL_SPEED_MAX := 600.0
const BALL_SPEED_INCREMENT := 25.0
const SEPARATION_EPSILON := 0.01
const PADDLE_WIDTH := 12.0
const PADDLE_HEIGHT := 80.0
const PADDLE_SPEED := 400.0
const PADDLE_P1_X := 40.0
const PADDLE_P2_X := 760.0
const MAX_BOUNCE_ANGLE_DEG := 50.0
const PADDLE_Y_MIN := PADDLE_HEIGHT / 2.0
const PADDLE_Y_MAX := PLAYFIELD_HEIGHT - PADDLE_HEIGHT / 2.0
const SCORE_TO_WIN := 11
const POINT_PAUSE_DURATION := 1.0
const AI_DEADZONE := 12.0
const AI_DEFAULT_HUMAN_SEAT := 1
const AI_DEFAULT_AI_SEAT := 2

const MODE_MENU := "MENU"
const MODE_PLAYING := "PLAYING"
const MODE_POINT_SCORED := "POINT_SCORED"
const MODE_PAUSED := "PAUSED"
const MODE_GAME_OVER := "GAME_OVER"

const CANONICAL_HELD := ["P1_UP", "P1_DOWN", "P2_UP", "P2_DOWN"]
const CANONICAL_EDGE := ["CONFIRM", "PAUSE", "RESTART"]


static func boot_state() -> Dictionary:
	return {
		"mode": MODE_MENU,
		"tick": 0,
		"elapsed_time": 0.0,
		"point_pause_remaining": 0.0,
		"mode_before_pause": null,
		"ball": {
			"x": PLAYFIELD_WIDTH / 2.0,
			"y": PLAYFIELD_HEIGHT / 2.0,
			"vx": 0.0,
			"vy": 0.0,
			"active": false,
		},
		"player1": {"y": PLAYFIELD_HEIGHT / 2.0, "score": 0},
		"player2": {"y": PLAYFIELD_HEIGHT / 2.0, "score": 0},
		"serving_player": 1,
		"winner": 0,
	}


static func clampf(value: float, lo: float, hi: float) -> float:
	if value < lo:
		return lo
	if value > hi:
		return hi
	return value


static func _reset_ball_for_serve(state: Dictionary, serving_player: int) -> void:
	var ball: Dictionary = state["ball"]
	ball["x"] = PLAYFIELD_WIDTH / 2.0
	ball["y"] = PLAYFIELD_HEIGHT / 2.0
	ball["active"] = false
	var speed := BALL_SPEED_INITIAL
	if serving_player == 1:
		ball["vx"] = speed
		ball["vy"] = 0.0
	else:
		ball["vx"] = -speed
		ball["vy"] = 0.0
	state["serving_player"] = serving_player


static func _start_match(state: Dictionary) -> Array:
	state["player1"]["score"] = 0
	state["player2"]["score"] = 0
	state["player1"]["y"] = PLAYFIELD_HEIGHT / 2.0
	state["player2"]["y"] = PLAYFIELD_HEIGHT / 2.0
	state["winner"] = 0
	state["tick"] = 0
	state["elapsed_time"] = 0.0
	state["point_pause_remaining"] = 0.0
	state["mode_before_pause"] = null
	_reset_ball_for_serve(state, 1)
	state["ball"]["active"] = true
	state["mode"] = MODE_PLAYING
	return ["ui_confirm"]


static func _full_reset(state: Dictionary) -> void:
	var boot := boot_state()
	state.clear()
	for k in boot.keys():
		state[k] = boot[k]


static func _move_paddles(state: Dictionary, held: Dictionary) -> void:
	var dy1 := 0.0
	if held.get("P1_UP", false):
		dy1 -= PADDLE_SPEED * DT
	if held.get("P1_DOWN", false):
		dy1 += PADDLE_SPEED * DT
	state["player1"]["y"] = clampf(state["player1"]["y"] + dy1, PADDLE_Y_MIN, PADDLE_Y_MAX)

	var dy2 := 0.0
	if held.get("P2_UP", false):
		dy2 -= PADDLE_SPEED * DT
	if held.get("P2_DOWN", false):
		dy2 += PADDLE_SPEED * DT
	state["player2"]["y"] = clampf(state["player2"]["y"] + dy2, PADDLE_Y_MIN, PADDLE_Y_MAX)


static func _wall_collisions(state: Dictionary, events: Array) -> void:
	var ball: Dictionary = state["ball"]
	if ball["y"] - BALL_RADIUS < 0.0:
		ball["y"] = BALL_RADIUS
		ball["vy"] = absf(ball["vy"])
		events.append("wall_hit")
	if ball["y"] + BALL_RADIUS > PLAYFIELD_HEIGHT:
		ball["y"] = PLAYFIELD_HEIGHT - BALL_RADIUS
		ball["vy"] = -absf(ball["vy"])
		events.append("wall_hit")


static func _paddle_overlap(ball: Dictionary, paddle_x: float, paddle_y: float) -> bool:
	var left := paddle_x - PADDLE_WIDTH / 2.0
	var right := paddle_x + PADDLE_WIDTH / 2.0
	var top := paddle_y - PADDLE_HEIGHT / 2.0
	var bottom := paddle_y + PADDLE_HEIGHT / 2.0
	var closest_x := clampf(ball["x"], left, right)
	var closest_y := clampf(ball["y"], top, bottom)
	var dx: float = ball["x"] - closest_x
	var dy: float = ball["y"] - closest_y
	return dx * dx + dy * dy <= BALL_RADIUS * BALL_RADIUS


static func _paddle_hit(state: Dictionary, which: int, events: Array) -> void:
	var ball: Dictionary = state["ball"]
	var paddle_x: float
	var paddle_y: float
	var direction: float
	if which == 1:
		if ball["vx"] >= 0.0:
			return
		paddle_x = PADDLE_P1_X
		paddle_y = state["player1"]["y"]
		direction = 1.0
	else:
		if ball["vx"] <= 0.0:
			return
		paddle_x = PADDLE_P2_X
		paddle_y = state["player2"]["y"]
		direction = -1.0
	if not _paddle_overlap(ball, paddle_x, paddle_y):
		return

	events.append("paddle_hit")
	var offset: float = (ball["y"] - paddle_y) / (PADDLE_HEIGHT / 2.0)
	offset = clampf(offset, -1.0, 1.0)
	var old_speed: float = sqrt(ball["vx"] * ball["vx"] + ball["vy"] * ball["vy"])
	var new_speed: float = minf(old_speed + BALL_SPEED_INCREMENT, BALL_SPEED_MAX)
	var angle_rad: float = deg_to_rad(offset * MAX_BOUNCE_ANGLE_DEG)
	ball["vx"] = new_speed * cos(angle_rad) * direction
	ball["vy"] = new_speed * sin(angle_rad)
	if which == 1:
		ball["x"] = paddle_x + PADDLE_WIDTH / 2.0 + BALL_RADIUS + SEPARATION_EPSILON
	else:
		ball["x"] = paddle_x - PADDLE_WIDTH / 2.0 - BALL_RADIUS - SEPARATION_EPSILON


static func _handle_point_scored(state: Dictionary, scored_by: int, events: Array) -> void:
	if state["player1"]["score"] >= SCORE_TO_WIN or state["player2"]["score"] >= SCORE_TO_WIN:
		state["mode"] = MODE_GAME_OVER
		state["winner"] = 1 if state["player1"]["score"] >= SCORE_TO_WIN else 2
		state["ball"]["active"] = false
		events.append("game_over")
		return
	state["mode"] = MODE_POINT_SCORED
	state["point_pause_remaining"] = POINT_PAUSE_DURATION
	_reset_ball_for_serve(state, 2 if scored_by == 1 else 1)


static func _check_scoring(state: Dictionary, events: Array) -> void:
	var ball: Dictionary = state["ball"]
	if ball["x"] + BALL_RADIUS < 0.0:
		state["player2"]["score"] = int(state["player2"]["score"]) + 1
		events.append("score")
		_handle_point_scored(state, 2, events)
		return
	if ball["x"] - BALL_RADIUS > PLAYFIELD_WIDTH:
		state["player1"]["score"] = int(state["player1"]["score"]) + 1
		events.append("score")
		_handle_point_scored(state, 1, events)


static func _playing_physics(state: Dictionary, held: Dictionary, events: Array) -> void:
	_move_paddles(state, held)
	var ball: Dictionary = state["ball"]
	if ball["active"]:
		ball["x"] = ball["x"] + ball["vx"] * DT
		ball["y"] = ball["y"] + ball["vy"] * DT
		_wall_collisions(state, events)
		_paddle_hit(state, 1, events)
		_paddle_hit(state, 2, events)
		_check_scoring(state, events)
	if state["mode"] == MODE_PLAYING or state["mode"] == MODE_POINT_SCORED:
		state["tick"] = int(state["tick"]) + 1
		state["elapsed_time"] = float(state["tick"]) * DT


static func _held_set(held: Array) -> Dictionary:
	var out := {}
	for a in held:
		var s := str(a)
		if s in CANONICAL_HELD:
			out[s] = true
	return out


static func _pressed_set(pressed: Array) -> Dictionary:
	var out := {}
	for a in pressed:
		var s := str(a)
		if s in CANONICAL_EDGE:
			out[s] = true
	return out


## Advance one fixed tick. Mutates state. Returns event name array.
static func step(state: Dictionary, held: Array = [], pressed: Array = []) -> Array:
	var held_set := _held_set(held)
	var pressed_set := _pressed_set(pressed)
	var events: Array = []
	var mode: String = str(state["mode"])

	if mode == MODE_MENU:
		if pressed_set.get("RESTART", false):
			_full_reset(state)
			return events
		if pressed_set.get("CONFIRM", false):
			events.append_array(_start_match(state))
		return events

	if mode == MODE_PLAYING:
		if pressed_set.get("RESTART", false):
			_full_reset(state)
			return events
		if pressed_set.get("PAUSE", false):
			state["mode_before_pause"] = MODE_PLAYING
			state["mode"] = MODE_PAUSED
			return events
		_playing_physics(state, held_set, events)
		return events

	if mode == MODE_POINT_SCORED:
		if pressed_set.get("RESTART", false):
			_full_reset(state)
			return events
		if pressed_set.get("PAUSE", false):
			state["mode_before_pause"] = MODE_POINT_SCORED
			state["mode"] = MODE_PAUSED
			return events
		_move_paddles(state, held_set)
		state["point_pause_remaining"] = float(state["point_pause_remaining"]) - DT
		if state["point_pause_remaining"] <= 0.0:
			state["point_pause_remaining"] = 0.0
			state["mode"] = MODE_PLAYING
			state["ball"]["active"] = true
		state["tick"] = int(state["tick"]) + 1
		state["elapsed_time"] = float(state["tick"]) * DT
		return events

	if mode == MODE_PAUSED:
		if pressed_set.get("RESTART", false):
			_full_reset(state)
			return events
		if pressed_set.get("PAUSE", false):
			var prev = state["mode_before_pause"]
			state["mode"] = MODE_PLAYING if prev == null else str(prev)
			state["mode_before_pause"] = null
		return events

	if mode == MODE_GAME_OVER:
		if pressed_set.get("CONFIRM", false):
			events.append("ui_confirm")
			_full_reset(state)
			return events
		if pressed_set.get("RESTART", false):
			_full_reset(state)

	return events


## Canonical offline AI (specs/pong/AI_SPEC.md).
static func ai_held(state: Dictionary, seat: int = AI_DEFAULT_AI_SEAT) -> Array:
	var mode: String = str(state["mode"])
	if mode != MODE_PLAYING and mode != MODE_POINT_SCORED:
		return []
	var paddle_y: float = state["player1"]["y"] if seat == 1 else state["player2"]["y"]
	var ball: Dictionary = state["ball"]
	var approaching: bool = (seat == 1 and ball["vx"] < 0.0) or (seat == 2 and ball["vx"] > 0.0)
	var target_y: float
	if ball["active"] and approaching:
		target_y = ball["y"]
	else:
		target_y = PLAYFIELD_HEIGHT / 2.0
	var delta: float = target_y - paddle_y
	var up := "P1_UP" if seat == 1 else "P2_UP"
	var down := "P1_DOWN" if seat == 1 else "P2_DOWN"
	if delta < -AI_DEADZONE:
		return [up]
	if delta > AI_DEADZONE:
		return [down]
	return []
