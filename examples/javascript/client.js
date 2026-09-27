/**
 * Polished browser canvas client for MultiPong.
 * Dual-mode: online (authoritative server) or offline (local sim + canonical AI).
 * See specs/pong/PROTOCOL.md and specs/pong/AI_SPEC.md.
 */
import {
  bootState,
  step,
  aiHeld,
  C as SIM,
} from "../../reference/js/pong_sim.js";

const C = {
  playfield: {
    width: SIM.PLAYFIELD_WIDTH,
    height: SIM.PLAYFIELD_HEIGHT,
    background_color: "#0B0E14",
    center_line_color: "#2A3344",
    center_line_width: 4,
    center_line_dash_length: 16,
    center_line_gap: 12,
  },
  ball: { radius: SIM.BALL_RADIUS, color: "#F2F5F8" },
  paddle: {
    width: SIM.PADDLE_WIDTH,
    height: SIM.PADDLE_HEIGHT,
    color: "#E8EEF5",
    p1_x: SIM.PADDLE_P1_X,
    p2_x: SIM.PADDLE_P2_X,
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
const DT = SIM.DT;
const MAX_STEPS = 5;
const MAX_FRAME = 0.25;
const AI_SEAT = SIM.AI_DEFAULT_AI_SEAT;
const HUMAN_SEAT = SIM.AI_DEFAULT_HUMAN_SEAT;

const canvas = document.getElementById("c");
const ctx = canvas.getContext("2d");
const statusEl = document.getElementById("status");
const form = document.getElementById("join-form");
const connectBtn = document.getElementById("connect-btn");
const disconnectBtn = document.getElementById("disconnect-btn");
const offlineBtn = document.getElementById("offline-btn");
const nameInput = document.getElementById("name");
const roomInput = document.getElementById("room");
const urlInput = document.getElementById("url");

const params = new URLSearchParams(location.search);
if (params.get("name")) nameInput.value = params.get("name");
if (params.get("room")) roomInput.value = params.get("room");
if (params.get("url")) urlInput.value = params.get("url");

/** @type {"idle" | "online" | "offline"} */
let mode = "idle";
let ws = null;
let state = null;
let you = null;
let seats = null;
let status = "Choose Offline or Connect";
const held = new Set();
const pressed = [];
let accum = 0;
let lastFrame = performance.now();

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

function setControlsBusy(busy) {
  connectBtn.disabled = busy;
  disconnectBtn.disabled = !busy;
  offlineBtn.disabled = busy;
  nameInput.disabled = busy;
  roomInput.disabled = busy;
  urlInput.disabled = busy;
}

window.addEventListener("keydown", (e) => {
  if (keyMap[e.code]) {
    held.add(keyMap[e.code]);
    e.preventDefault();
  }
  if (e.code === "Enter" || e.code === "Space") {
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

function startOffline() {
  if (ws) disconnect();
  mode = "offline";
  state = bootState();
  you = HUMAN_SEAT;
  seats = null;
  accum = 0;
  lastFrame = performance.now();
  setControlsBusy(true);
  disconnectBtn.disabled = false;
  setStatus("Offline vs AI · seat P1");
}

function connect() {
  if (mode === "offline") stopOffline();
  if (ws) disconnect();
  const url = urlInput.value.trim() || "ws://127.0.0.1:8765";
  const room = roomInput.value.trim() || "demo";
  const name = nameInput.value.trim() || "js";
  mode = "online";
  setStatus("Connecting…");
  setControlsBusy(true);

  try {
    ws = new WebSocket(url);
  } catch (err) {
    setStatus("Connection failed: " + err.message);
    mode = "idle";
    setControlsBusy(false);
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
    if (mode === "online") {
      mode = "idle";
      setControlsBusy(false);
      if (!status.startsWith("Error")) setStatus("Disconnected");
    }
  };
  ws.onerror = () => {
    setStatus("Connection error — is the server running?");
  };
}

function stopOffline() {
  mode = "idle";
  state = null;
  you = null;
  seats = null;
  accum = 0;
  setControlsBusy(false);
  setStatus("Choose Offline or Connect");
}

function disconnect() {
  if (mode === "offline") {
    stopOffline();
    return;
  }
  if (ws) {
    ws.close();
    ws = null;
  }
  mode = "idle";
  state = null;
  you = null;
  seats = null;
  setControlsBusy(false);
  setStatus("Disconnected");
}

form.addEventListener("submit", (e) => {
  e.preventDefault();
  connect();
});
disconnectBtn.addEventListener("click", () => disconnect());
offlineBtn.addEventListener("click", () => startOffline());

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

    const gameMode = state.mode;
    if (gameMode === "MENU") {
      fillTextCentered(
        C.ui.title,
        C.ui.title_center[0],
        C.ui.title_center[1],
        C.ui.title_font_size,
        C.ui.text_color
      );
      const sub =
        mode === "offline"
          ? C.ui.menu_subtitle
          : seats && seats.players < 2
            ? "Waiting for opponent…"
            : C.ui.menu_subtitle;
      fillTextCentered(
        sub,
        C.ui.subtitle_center[0],
        C.ui.subtitle_center[1],
        C.ui.subtitle_font_size,
        C.ui.text_color
      );
    } else if (gameMode === "PAUSED") {
      fillTextCentered(C.ui.paused_text, W / 2, H / 2, C.ui.title_font_size, C.ui.text_color);
    } else if (gameMode === "GAME_OVER") {
      const msg = state.winner === 1 ? C.ui.game_over_p1 : C.ui.game_over_p2;
      fillTextCentered(msg, W / 2, H / 2 - 24, C.ui.title_font_size, C.ui.text_color);
      fillTextCentered(
        C.ui.game_over_hint,
        W / 2,
        H / 2 + 28,
        C.ui.subtitle_font_size,
        C.ui.text_color
      );
    } else if (gameMode === "POINT_SCORED") {
      fillTextCentered("Point!", W / 2, H / 2, C.ui.subtitle_font_size, C.ui.text_color);
    }
  } else {
    fillTextCentered("MULTIPONG", W / 2, H / 2 - 20, 36, C.ui.text_color);
    fillTextCentered("Offline vs AI · or Connect", W / 2, H / 2 + 24, 16, HUD);
  }
}

function tickOffline(now) {
  let frameDt = (now - lastFrame) / 1000;
  lastFrame = now;
  if (frameDt > MAX_FRAME) frameDt = MAX_FRAME;
  accum += frameDt;
  let steps = 0;
  const edge = pressed.splice(0, pressed.length);
  while (accum >= DT && steps < MAX_STEPS) {
    const human = [];
    if (held.has("UP")) human.push("P1_UP");
    if (held.has("DOWN")) human.push("P1_DOWN");
    const ai = aiHeld(state, AI_SEAT);
    const allHeld = [...new Set([...human, ...ai])];
    step(state, allHeld, steps === 0 ? edge : []);
    accum -= DT;
    steps++;
  }
}

function loop(now) {
  if (mode === "offline" && state) {
    tickOffline(now);
  } else if (mode === "online" && ws && ws.readyState === WebSocket.OPEN) {
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

if (params.get("offline") === "1") {
  startOffline();
} else if (params.get("autostart") === "1" || params.get("name")) {
  connect();
}

window.MultiPongClient = {
  getState: () => state,
  getYou: () => you,
  getMode: () => mode,
  connect,
  disconnect,
  startOffline,
};
