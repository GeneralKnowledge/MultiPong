# GameMaker — local-editor stub

Not a dual-mode client you can run from this repo. Sketch for wiring WebSockets inside GameMaker on your machine.

GameMaker supports WebSockets via `network_*` async networking or marketplace extensions (varies by runtime).

## Message sketch (GML)

```gml
/// Create event
url = "ws://127.0.0.1:8765";
// connect with your chosen WS extension, then:
send_json = "{\"type\":\"join\",\"room\":\"demo\",\"name\":\"gamemaker\"}";

/// Step event — seat-relative
held = [];
if (keyboard_check(ord("W")) || keyboard_check(vk_up)) array_push(held, "UP");
if (keyboard_check(ord("S")) || keyboard_check(vk_down)) array_push(held, "DOWN");
pressed = [];
if (keyboard_check_pressed(vk_enter)) array_push(pressed, "CONFIRM");
// build JSON array strings, then:
// network_send_raw / extension send of
// {"type":"input","held":[...],"pressed":[...]}

/// Async networking event
// parse buffer JSON; on type=="state", set paddle/ball instance coordinates
// from state.player1.y, state.player2.y, state.ball.x/y (Y-down canonical)
```

Treat this folder as the contract; wire it to whichever WebSocket extension your GameMaker version uses.  
For a runnable dual-mode example in Cursor, use [../python/](../python/) or [../lua/](../lua/).
