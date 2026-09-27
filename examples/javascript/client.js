/* Minimal browser WebSocket client — same protocol as every other example.
 * Reuse from Phaser (as a scene helper) or RPG Maker plugin code.
 */
(() => {
  const URL = new URLSearchParams(location.search).get("url") || "ws://127.0.0.1:8765";
  const ROOM = new URLSearchParams(location.search).get("room") || "demo";
  const NAME = new URLSearchParams(location.search).get("name") || "js";

  const canvas = document.getElementById("c");
  const ctx = canvas.getContext("2d");
  const hud = document.getElementById("hud");

  let state = null;
  let you = null;
  const held = new Set();
  const pressed = [];

  const keyMap = {
    KeyW: "UP",
    ArrowUp: "UP",
    KeyS: "DOWN",
    ArrowDown: "DOWN",
  };

  window.addEventListener("keydown", (e) => {
    if (keyMap[e.code]) held.add(keyMap[e.code]);
    if (e.code === "Enter" || e.code === "Space") pressed.push("CONFIRM");
    if (e.code === "KeyP" || e.code === "Escape") pressed.push("PAUSE");
    if (e.code === "KeyR") pressed.push("RESTART");
  });
  window.addEventListener("keyup", (e) => {
    if (keyMap[e.code]) held.delete(keyMap[e.code]);
  });

  const ws = new WebSocket(URL);
  ws.onopen = () => {
    ws.send(JSON.stringify({ type: "join", room: ROOM, name: NAME }));
    hud.textContent = "Joined — waiting for welcome";
  };
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.type === "welcome") {
      you = msg.player;
      hud.textContent = `You are player ${you} in room ${msg.room}`;
    } else if (msg.type === "state") {
      state = msg.state;
      you = msg.you ?? you;
    } else if (msg.type === "error") {
      hud.textContent = "Error: " + msg.message;
    }
  };
  ws.onclose = () => {
    hud.textContent = "Disconnected";
  };

  function draw() {
    ctx.fillStyle = "#0b0e14";
    ctx.fillRect(0, 0, 800, 600);
    if (!state) return;
    ctx.fillStyle = "#2a3344";
    for (let y = 0; y < 600; y += 28) ctx.fillRect(398, y, 4, 16);
    ctx.fillStyle = "#e8eef5";
    ctx.fillRect(40 - 6, state.player1.y - 40, 12, 80);
    ctx.fillRect(760 - 6, state.player2.y - 40, 12, 80);
    ctx.beginPath();
    ctx.fillStyle = "#f2f5f8";
    ctx.arc(state.ball.x, state.ball.y, 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.font = "20px monospace";
    ctx.fillText(
      `${state.player1.score} - ${state.player2.score}  [${state.mode}] you=P${you}`,
      240,
      36
    );
  }

  function loop() {
    if (ws.readyState === WebSocket.OPEN) {
      const payload = { type: "input", held: [...held], pressed: pressed.splice(0) };
      ws.send(JSON.stringify(payload));
    }
    draw();
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  // Export for Phaser / RPG Maker reuse
  window.MultiPongClient = { getState: () => state, getYou: () => you };
})();
