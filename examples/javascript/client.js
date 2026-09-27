/**
 * Polished browser canvas client for MultiPong.
 * Speaks specs/pong/PROTOCOL.md — online play only (server is authoritative).
 * Constants mirror specs/pong/constants.json.
 */
(() => {
  const C = {
    playfield: {
      width: 800,
      height: 600,
      background_color: "#0B0E14",
      center_line_color: "#2A3344",
      center_line_width: 4,
      center_line_dash_length: 16,
      center_line_gap: 12,
    },
    ball: { radius: 8, color: "#F2F5F8" },
    paddle: {
      width: 12,
      height: 80,
      color: "#E8EEF5",
      p1_x: 40,
      p2_x: 760,
    },
    scoring: {
      score_color: "#F2F5F8",
      score_font_size: 32,
      score_p1_center: [300, 48],
      score_p2_center: [500, 48],
    },
    ui: {
      title: "PONG",
      menu_subtitle: "Press Enter",
      paused_text: "PAUSED",
      game_over_p1: "PLAYER 1 WINS",
      game_over_p2: "PLAYER 2 WINS",
      game_over_hint: "Press Enter",
      text_color: "#F2F5F8",
      title_font_size: 48,
      subtitle_font_size: 16,
      title_center: [400, 220],
      subtitle_center: [400, 300],
    },
  };

  const YOU_OUTLINE = "#7FD0C5";
  const HUD = "#8B95A8";

  const canvas = document.getElementById("c");
  const ctx = canvas.getContext("2d");
  const statusEl = document.getElementById("status");
  const form = document.getElementById("join-form");
  const connectBtn = document.getElementById("connect-btn");
  const disconnectBtn = document.getElementById("disconnect-btn");
  const nameInput = document.getElementById("name");
  const roomInput = document.getElementById("room");
  const urlInput = document.getElementById("url");

  // Prefill from query string
  const params = new URLSearchParams(location.search);
  if (params.get("name")) nameInput.value = params.get("name");
  if (params.get("room")) roomInput.value = params.get("room");
  if (params.get("url")) urlInput.value = params.get("url");

  let ws = null;
  let state = null;
  let you = null;
  let seats = null;
  let status = "Not connected";
  const held = new Set();
  const pressed = [];

  const keyMap = {
    KeyW: "UP",
    ArrowUp: "UP",
    KeyS: "DOWN",
    ArrowDown: "DOWN",
  };

  function setStatus(text) {
    status = text;
    statusEl.textContent = text;
  }

  function setConnected(on) {
    connectBtn.disabled = on;
    disconnectBtn.disabled = !on;
    nameInput.disabled = on;
    roomInput.disabled = on;
    urlInput.disabled = on;
  }

  window.addEventListener("keydown", (e) => {
    if (keyMap[e.code]) {
      held.add(keyMap[e.code]);
      e.preventDefault();
    }
    if (e.code === "Enter" || e.code === "Space") {
      // Don't steal Enter while typing in the form
      if (document.activeElement && document.activeElement.tagName === "INPUT") return;
      pressed.push("CONFIRM");
      e.preventDefault();
    }
    if (e.code === "KeyP" || e.code === "Escape") {
      if (document.activeElement && document.activeElement.tagName === "INPUT") return;
      pressed.push("PAUSE");
      e.preventDefault();
    }
    if (e.code === "KeyR") {
      if (document.activeElement && document.activeElement.tagName === "INPUT") return;
      pressed.push("RESTART");
      e.preventDefault();
    }
  });

  window.addEventListener("keyup", (e) => {
    if (keyMap[e.code]) {
      held.delete(keyMap[e.code]);
      e.preventDefault();
    }
  });

  function connect() {
    if (ws) disconnect();
    const url = urlInput.value.trim() || "ws://127.0.0.1:8765";
    const room = roomInput.value.trim() || "demo";
    const name = nameInput.value.trim() || "js";
    setStatus("Connecting…");
    setConnected(true);

    try {
      ws = new WebSocket(url);
    } catch (err) {
      setStatus("Connection failed: " + err.message);
      setConnected(false);
      return;
    }

    ws.onopen = () => {
      ws.send(JSON.stringify({ type: "join", room, name }));
      setStatus(`Connected · room ${room}`);
    };
    ws.onmessage = (ev) => {
      let msg;
      try {
        msg = JSON.parse(ev.data);
      } catch {
        return;
      }
      if (msg.type === "welcome") {
        you = msg.player;
        setStatus(`Connected · room ${msg.room} · you are P${you}`);
      } else if (msg.type === "state") {
        state = msg.state;
        if (msg.you) you = msg.you;
      } else if (msg.type === "room") {
        seats = msg;
        const n = msg.players || 0;
        if (n < 2) setStatus(`Connected · waiting for opponent (${n}/2)`);
        else setStatus(`Connected · room ${msg.room} · 2/2`);
      } else if (msg.type === "error") {
        setStatus("Error: " + msg.message);
      }
    };
    ws.onclose = () => {
      ws = null;
      setConnected(false);
      if (!status.startsWith("Error")) setStatus("Disconnected");
    };
    ws.onerror = () => {
      setStatus("Connection error — is the server running?");
    };
  }

  function disconnect() {
    if (ws) {
      ws.close();
      ws = null;
    }
    state = null;
    you = null;
    seats = null;
    setConnected(false);
    setStatus("Disconnected");
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    connect();
  });
  disconnectBtn.addEventListener("click", () => disconnect());

  function fillTextCentered(text, x, y, size, color) {
    ctx.fillStyle = color;
    ctx.font = `600 ${size}px "IBM Plex Mono", monospace`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, x, y);
  }

  function drawPaddle(cx, cy, highlight) {
    const w = C.paddle.width;
    const h = C.paddle.height;
    ctx.fillStyle = C.paddle.color;
    ctx.fillRect(cx - w / 2, cy - h / 2, w, h);
    if (highlight) {
      ctx.strokeStyle = YOU_OUTLINE;
      ctx.lineWidth = 2;
      ctx.strokeRect(cx - w / 2 + 0.5, cy - h / 2 + 0.5, w - 1, h - 1);
    }
  }

  function draw() {
    const W = C.playfield.width;
    const H = C.playfield.height;
    ctx.fillStyle = C.playfield.background_color;
    ctx.fillRect(0, 0, W, H);

    // centre line
    ctx.fillStyle = C.playfield.center_line_color;
    const dash = C.playfield.center_line_dash_length;
    const gap = C.playfield.center_line_gap;
    const lw = C.playfield.center_line_width;
    for (let y = 0; y < H; y += dash + gap) {
      ctx.fillRect(W / 2 - lw / 2, y, lw, dash);
    }

    if (state) {
      drawPaddle(C.paddle.p1_x, state.player1.y, you === 1);
      drawPaddle(C.paddle.p2_x, state.player2.y, you === 2);

      ctx.beginPath();
      ctx.fillStyle = C.ball.color;
      ctx.arc(state.ball.x, state.ball.y, C.ball.radius, 0, Math.PI * 2);
      ctx.fill();

      fillTextCentered(
        String(state.player1.score),
        C.scoring.score_p1_center[0],
        C.scoring.score_p1_center[1],
        C.scoring.score_font_size,
        C.scoring.score_color
      );
      fillTextCentered(
        String(state.player2.score),
        C.scoring.score_p2_center[0],
        C.scoring.score_p2_center[1],
        C.scoring.score_font_size,
        C.scoring.score_color
      );

      const mode = state.mode;
      if (mode === "MENU") {
        fillTextCentered(
          C.ui.title,
          C.ui.title_center[0],
          C.ui.title_center[1],
          C.ui.title_font_size,
          C.ui.text_color
        );
        const sub =
          seats && seats.players < 2 ? "Waiting for opponent…" : C.ui.menu_subtitle;
        fillTextCentered(
          sub,
          C.ui.subtitle_center[0],
          C.ui.subtitle_center[1],
          C.ui.subtitle_font_size,
          C.ui.text_color
        );
      } else if (mode === "PAUSED") {
        fillTextCentered(C.ui.paused_text, W / 2, H / 2, C.ui.title_font_size, C.ui.text_color);
      } else if (mode === "GAME_OVER") {
        const msg = state.winner === 1 ? C.ui.game_over_p1 : C.ui.game_over_p2;
        fillTextCentered(msg, W / 2, H / 2 - 24, C.ui.title_font_size, C.ui.text_color);
        fillTextCentered(
          C.ui.game_over_hint,
          W / 2,
          H / 2 + 28,
          C.ui.subtitle_font_size,
          C.ui.text_color
        );
      } else if (mode === "POINT_SCORED") {
        fillTextCentered("Point!", W / 2, H / 2, C.ui.subtitle_font_size, C.ui.text_color);
      }
    } else {
      fillTextCentered("MULTIPONG", W / 2, H / 2 - 20, 36, C.ui.text_color);
      fillTextCentered("Connect to start", W / 2, H / 2 + 24, 16, HUD);
    }
  }

  function loop() {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(
        JSON.stringify({
          type: "input",
          held: [...held],
          pressed: pressed.splice(0, pressed.length),
        })
      );
    }
    draw();
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  // Auto-connect when name/room provided via query (handy for two-tab tests)
  if (params.get("autostart") === "1" || params.get("name")) {
    connect();
  }

  window.MultiPongClient = {
    getState: () => state,
    getYou: () => you,
    connect,
    disconnect,
  };
})();
