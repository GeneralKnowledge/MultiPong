# Unreal Engine — local-editor stub

Not a dual-mode client you can run from this repo. Wire the protocol inside Unreal on your machine.

Unreal has no single universal Blueprint WebSocket node across all versions. Recommended paths:

## C++ (`unreal-cpp`)

1. Enable a WebSocket plugin (Epic’s `WebSockets` module, or a minimal third-party plugin).
2. On BeginPlay: connect to `ws://127.0.0.1:8765`.
3. Send:

```json
{"type":"join","room":"demo","name":"unreal"}
```

4. Each tick, send seat input from Enhanced Input:

```json
{"type":"input","held":["UP"],"pressed":[]}
```

5. On `state` message, `JsonObjectConverter` into a `USTRUCT` mirroring [state.schema.json](../../specs/pong/state.schema.json), then set actor locations. Convert Y if your scene is Z-up / Y-up.

## Blueprints (`unreal-blueprints`)

Keep **simulation off** online. Use Blueprints only to:

- drive UI / pawn visuals from the parsed `state`
- call a small C++ subsystem that owns the socket (more reliable than pure Blueprint JSON)

Pair with the Python or JS client for the second seat while iterating.  
For a runnable dual-mode example in Cursor, use [../python/](../python/) or [../lua/](../lua/).
