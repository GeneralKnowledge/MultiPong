# Phaser example

Phaser runs in the browser — use the shared JS client as the network layer.

1. Create a Phaser 3 game at 800×600.
2. Include or import the logic from [../javascript/client.js](../javascript/client.js) (or the same WebSocket join/input/state handlers).
3. In `update()`, set sprite positions from `window.MultiPongClient.getState()`.
4. Do not enable Arcade/Matter physics for the ball online.

Quick test without a Phaser scaffold: open [../javascript/index.html](../javascript/index.html).
