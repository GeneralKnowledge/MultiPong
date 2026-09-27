# Rust / Bevy example

Stdin-driven WebSocket client using the same JSON protocol. In Bevy, paste the join/input/state handling into a networking system and spawn sprites from `state`.

```bash
# server running first
cd examples/rust
cargo run -- --name rust1
# other terminal / other engine client joins room demo
```

Commands: `up`, `down`, `stop`, `confirm`, `pause`, `restart`, `quit`.
