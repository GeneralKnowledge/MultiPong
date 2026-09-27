# JavaScript / browser example

Works for **Phaser** and **RPG Maker** as the networking layer (canvas here is only a demo view).

```bash
# Server must allow browser origins; websockets lib does by default.
# Serve this folder (file:// often blocks WS on some browsers):
cd examples/javascript
python3 -m http.server 8080
# open http://127.0.0.1:8080/?name=alice
# second tab: http://127.0.0.1:8080/?name=bob
```

Query params: `url`, `room`, `name`.
