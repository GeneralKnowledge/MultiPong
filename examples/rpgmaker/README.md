# RPG Maker (MZ / MV) — local-editor stub

Not a dual-mode client you can run from this repo. Plugin sketch for RPG Maker on your machine.

RPG Maker runs JavaScript in Chromium/`nw.js` and can open WebSockets.

## Plugin approach

1. Copy the networking core from [../javascript/client.js](../javascript/client.js) into a plugin, e.g. `MultiPongNet.js`.
2. Expose:

```js
window.MultiPong = {
  connect(url, room, name) { /* join */ },
  setHeld(actions) { /* UP/DOWN */ },
  onState(cb) { /* subscribe */ },
  getState() { /* last state */ },
};
```

3. Map RPG Maker input (`Input.isPressed('up')`) to seat actions each `Scene_Map` / custom scene update.
4. Draw with PIXI sprites or a title-scene canvas using canonical coordinates.

You do **not** need the RPG Maker battle system — use a blank map or custom scene as a host for the canvas.

For a quick validation without a full RPG Maker project, use the browser example:

```bash
cd examples/javascript && python3 -m http.server 8080
```

Or run the Love2D / Python dual-mode clients in this repo.
