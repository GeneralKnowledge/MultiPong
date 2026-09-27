# Unity (C#) example

1. Create a Unity project (2021.3+ or Unity 6).
2. Add a WebSocket package (e.g. [NativeWebSocket](https://github.com/endel/NativeWebSocket)).
3. Drop `MultiPongClient.cs` on a GameObject; wire `_socket` send/receive to that library using `BuildJoinJson` / `BuildInputJson` / `OnMessage`.
4. Render paddles/ball from `State` (convert Y if needed).
5. Run two Play-mode instances (ParrelSync) or pair with the JS/Python client against `backend/server.py`.

No Unity physics — online mode only displays server state.
