# Godot (GDScript) example

1. Create a Godot **4.x** project.
2. Copy `MultiPongClient.gd` into the project.
3. Add a Node, attach the script, set `server_url` / `room` / `name`.
4. Render using `get_game_state()` (canonical 800×600, Y-down — flip if your camera is Y-up).
5. Run the backend, then run two game instances (or one Godot + one JS/Python client).

Uses Godot’s built-in `WebSocketPeer`. No extra addons.
