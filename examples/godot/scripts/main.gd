extends Node2D
## Dual-mode MultiPong client for Godot 4.
## Offline: PongSim + simple_track AI. Online: authoritative WebSocket server.
## No Godot physics for gameplay.

enum Mode { IDLE, OFFLINE, ONLINE }

const MAX_STEPS := 5
const MAX_FRAME := 0.25
const YOU_COLOR := Color("7FD0C5")
const BG := Color("0B0E14")
const LINE := Color("2A3344")
const PAD := Color("E8EEF5")
const BALL_COLOR := Color("F2F5F8")
const TEXT_COLOR := Color("F2F5F8")
const HUD_COLOR := Color("8B95A8")

var _mode: Mode = Mode.IDLE
var _state: Dictionary = {}
var _you: int = 0
var _seats_players: int = 0
var _status: String = "Offline vs AI · seat P1"
var _accum: float = 0.0
var _held_edge: Array[String] = []

var _ws := WebSocketPeer.new()
var _joined := false
var _server_url := "ws://127.0.0.1:8765"
var _room := "demo"
var _player_name := "godot"

@onready var _status_label: Label = $UI/Status
@onready var _hint_label: Label = $UI/Hint


func _ready() -> void:
	_parse_args()
	_apply_window()
	# Beginner-friendly: editor Run / no flags → offline vs AI immediately.
	if _mode == Mode.ONLINE:
		_start_online()
	else:
		_start_offline()
	queue_redraw()


func _parse_args() -> void:
	var offline := false
	var online := false
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--offline":
				offline = true
			"--online":
				online = true
			"--url":
				i += 1
				if i < args.size():
					_server_url = args[i]
			"--room":
				i += 1
				if i < args.size():
					_room = args[i]
			"--name":
				i += 1
				if i < args.size():
					_player_name = args[i]
		i += 1
	if online and not offline:
		_mode = Mode.ONLINE
	else:
		# Default offline (also when both omitted — best for Godot editor ▶ Run)
		_mode = Mode.OFFLINE


func _apply_window() -> void:
	DisplayServer.window_set_title("MultiPong — Godot")
	get_window().size = Vector2i(int(PongSim.PLAYFIELD_WIDTH), int(PongSim.PLAYFIELD_HEIGHT))
	get_window().content_scale_size = Vector2i(
		int(PongSim.PLAYFIELD_WIDTH), int(PongSim.PLAYFIELD_HEIGHT)
	)


func _start_offline() -> void:
	_mode = Mode.OFFLINE
	_state = PongSim.boot_state()
	_you = PongSim.AI_DEFAULT_HUMAN_SEAT
	_accum = 0.0
	_status = "Offline vs AI · seat P1"
	_joined = false


func _start_online() -> void:
	_mode = Mode.ONLINE
	_state = {}
	_you = 0
	_seats_players = 0
	_joined = false
	_status = "Connecting…"
	var err := _ws.connect_to_url(_server_url)
	if err != OK:
		_status = "Connection failed: %s" % err
		_mode = Mode.IDLE


func _stop() -> void:
	if _mode == Mode.ONLINE:
		_ws.close()
	_joined = false
	_mode = Mode.IDLE
	_state = {}
	_you = 0
	_status = "Stopped · O offline · C connect"


func _process(delta: float) -> void:
	if _mode == Mode.OFFLINE:
		_tick_offline(delta)
	elif _mode == Mode.ONLINE:
		_tick_online()
	_update_hud()
	queue_redraw()


func _tick_offline(delta: float) -> void:
	var frame_dt := minf(delta, MAX_FRAME)
	_accum += frame_dt
	var steps := 0
	var edge := _held_edge.duplicate()
	_held_edge.clear()
	while _accum >= PongSim.DT and steps < MAX_STEPS:
		var human: Array = []
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			human.append("P1_UP")
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			human.append("P1_DOWN")
		var held: Array = human.duplicate()
		for a in PongSim.ai_held(_state, PongSim.AI_DEFAULT_AI_SEAT):
			if a not in held:
				held.append(a)
		var pressed: Array = edge if steps == 0 else []
		PongSim.step(_state, held, pressed)
		_accum -= PongSim.DT
		steps += 1


func _tick_online() -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _joined:
			_send({"type": "join", "room": _room, "name": _player_name})
			_joined = true
			_status = "Connected · room %s" % _room
		while _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet().get_string_from_utf8()
			var msg: Variant = JSON.parse_string(raw)
			if typeof(msg) == TYPE_DICTIONARY:
				_on_message(msg)
		var held: Array = []
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			held.append("UP")
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			held.append("DOWN")
		var pressed := _held_edge.duplicate()
		_held_edge.clear()
		_send({"type": "input", "held": held, "pressed": pressed})
	elif st == WebSocketPeer.STATE_CLOSED:
		if _joined:
			_status = "Disconnected"
		_joined = false


func _on_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"welcome":
			_you = int(msg.get("player", 0))
			_status = "Connected · room %s · you are P%d" % [str(msg.get("room", _room)), _you]
		"state":
			var s: Variant = msg.get("state")
			if typeof(s) == TYPE_DICTIONARY:
				_state = s
			if msg.has("you"):
				_you = int(msg["you"])
		"room":
			_seats_players = int(msg.get("players", 0))
			if _seats_players < 2:
				_status = "Connected · waiting for opponent (%d/2)" % _seats_players
			else:
				_status = "Connected · room %s · 2/2" % str(msg.get("room", _room))
		"error":
			_status = "Error: %s" % str(msg.get("message"))


func _send(obj: Dictionary) -> void:
	_ws.send_text(JSON.stringify(obj))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_O:
				if _mode != Mode.OFFLINE:
					_stop()
					_start_offline()
			KEY_C:
				if _mode != Mode.ONLINE:
					_stop()
					_start_online()
			KEY_ENTER, KEY_SPACE:
				_held_edge.append("CONFIRM")
			KEY_P, KEY_ESCAPE:
				if _mode == Mode.IDLE:
					return
				_held_edge.append("PAUSE")
			KEY_R:
				_held_edge.append("RESTART")
			KEY_Q:
				if event.ctrl_pressed:
					get_tree().quit()


func _update_hud() -> void:
	var seat := ("P%d" % _you) if _you else "—"
	_status_label.text = "%s   seat %s" % [_status, seat]
	_hint_label.text = "W/S or ↑/↓ · Enter · P · R · O offline · C connect"


func _draw() -> void:
	draw_rect(Rect2(0, 0, PongSim.PLAYFIELD_WIDTH, PongSim.PLAYFIELD_HEIGHT), BG, true)
	var y := 0.0
	while y < PongSim.PLAYFIELD_HEIGHT:
		draw_rect(
			Rect2(PongSim.PLAYFIELD_WIDTH / 2.0 - 2.0, y, 4.0, 16.0),
			LINE,
			true
		)
		y += 16.0 + 12.0

	if _state.is_empty():
		_draw_centered("MULTIPONG", Vector2(400, 280), 36, TEXT_COLOR)
		_draw_centered("Connecting… · or press O for offline", Vector2(400, 324), 16, HUD_COLOR)
		return

	_draw_paddle(PongSim.PADDLE_P1_X, float(_state["player1"]["y"]), _you == 1)
	_draw_paddle(PongSim.PADDLE_P2_X, float(_state["player2"]["y"]), _you == 2)
	var ball: Dictionary = _state["ball"]
	draw_circle(Vector2(ball["x"], ball["y"]), PongSim.BALL_RADIUS, BALL_COLOR)

	_draw_centered(str(_state["player1"]["score"]), Vector2(300, 48), 32, TEXT_COLOR)
	_draw_centered(str(_state["player2"]["score"]), Vector2(500, 48), 32, TEXT_COLOR)

	var game_mode := str(_state["mode"])
	match game_mode:
		"MENU":
			_draw_centered("PONG", Vector2(400, 220), 48, TEXT_COLOR)
			var sub := "Press Enter"
			if _mode == Mode.ONLINE and _seats_players < 2:
				sub = "Waiting for opponent…"
			_draw_centered(sub, Vector2(400, 300), 16, TEXT_COLOR)
		"PAUSED":
			_draw_centered("PAUSED", Vector2(400, 300), 48, TEXT_COLOR)
		"GAME_OVER":
			var msg := "PLAYER 1 WINS" if int(_state["winner"]) == 1 else "PLAYER 2 WINS"
			_draw_centered(msg, Vector2(400, 276), 48, TEXT_COLOR)
			_draw_centered("Press Enter", Vector2(400, 328), 16, TEXT_COLOR)
		"POINT_SCORED":
			_draw_centered("Point!", Vector2(400, 300), 16, TEXT_COLOR)


func _draw_paddle(cx: float, cy: float, highlight: bool) -> void:
	var r := Rect2(
		cx - PongSim.PADDLE_WIDTH / 2.0,
		cy - PongSim.PADDLE_HEIGHT / 2.0,
		PongSim.PADDLE_WIDTH,
		PongSim.PADDLE_HEIGHT
	)
	draw_rect(r, PAD, true)
	if highlight:
		draw_rect(r, YOU_COLOR, false, 2.0)


func _draw_centered(text: String, center: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var ts := float(size)
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts)
	draw_string(
		font,
		Vector2(center.x - sz.x * 0.5, center.y + sz.y * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		ts,
		color
	)
