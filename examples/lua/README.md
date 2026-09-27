# Love2D (Lua) example

Love2D does not ship WebSockets. Options:

1. Vendor a small Lua WebSocket client and require it from `main.lua`
2. Pair Love2D rendering with the [javascript](../javascript/) client as a protocol reference
3. Use a FFI/native library

`main.lua` shows join/input message shapes and seat-relative controls. Prefer a real JSON library (`dkjson`) when you flesh this out.

```bash
love examples/lua
```
