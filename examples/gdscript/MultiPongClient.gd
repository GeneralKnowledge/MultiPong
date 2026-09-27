extends Node
## Godot 4 multiplayer client for MultiPong.
## Protocol: specs/pong/PROTOCOL.md

class_name MultiPongClient

@export var server_url: String = "ws://127.0.0.1:8765"
@export var room: String = "demo"
@export var player_name: String = "godot"

var _ws := WebSocketPeer.new()
var _state: Variant = null
var _you: int = 0
var _held: Array[String] = []
var _pressed: Array[String] = []
var _joined := false

func _ready() -> void:
	var err := _ws.connect_to_url(server_url)
	if err != OK:
		push_error("WebSocket connect failed: %s" % err)

func _process(_dt: float) -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _joined:
			_send({"type": "join", "room": room, "name": player_name})
			_joined = true
		while _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet().get_string_from_utf8()
			var msg: Variant = JSON.parse_string(raw)
			if typeof(msg) == TYPE_DICTIONARY:
				_on_message(msg)
		_held.clear()
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			_held.append("UP")
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			_held.append("DOWN")
		_send({"type": "input", "held": _held.duplicate(), "pressed": _pressed.duplicate()})
		_pressed.clear()
	elif st == WebSocketPeer.STATE_CLOSED:
		_joined = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_SPACE:
				_pressed.append("CONFIRM")
			KEY_P, KEY_ESCAPE:
				_pressed.append("PAUSE")
			KEY_R:
				_pressed.append("RESTART")

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"welcome":
			_you = int(msg.get("player", 0))
			print("Joined as player ", _you)
		"state":
			_state = msg.get("state")
			_you = int(msg.get("you", _you))
		"error":
			push_error(str(msg.get("message")))

func _send(obj: Dictionary) -> void:
	_ws.send_text(JSON.stringify(obj))

func get_game_state() -> Variant:
	return _state

func get_seat() -> int:
	return _you
