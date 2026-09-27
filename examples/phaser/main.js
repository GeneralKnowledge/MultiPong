/**
 * Phaser 3 dual-mode MultiPong client.
 * Offline: reference/js sim + canonical simple_track AI.
 * Online: authoritative WebSocket server (PROTOCOL.md).
 * Rendering only — Arcade/Matter physics are NOT used.
 */
import {
  bootState,
  step,
  aiHeld,
  C as SIM,
} from "../../reference/js/pong_sim.js";

const PF_W = SIM.PLAYFIELD_WIDTH;
const PF_H = SIM.PLAYFIELD_HEIGHT;
const DT = SIM.DT;
const MAX_STEPS = 5;
const MAX_FRAME = 0.25;
const AI_SEAT = SIM.AI_DEFAULT_AI_SEAT;
const HUMAN_SEAT = SIM.AI_DEFAULT_HUMAN_SEAT;

const COLORS = {
  bg: 0x0b0e14,
  line: 0x2a3344,
  pad: 0xe8eef5,
  ball: 0xf2f5f8,
  text: "#f2f5f8",
  hud: "#8b95a8",
  you: 0x7fd0c5,
};

const UI = {
  title: "PONG",
  menu_subtitle: "Press Enter",
  paused_text: "PAUSED",
  game_over_p1: "PLAYER 1 WINS",
  game_over_p2: "PLAYER 2 WINS",
  game_over_hint: "Press Enter",
};

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
  if (e.code === "KeyW" || e.code === "ArrowUp") {
    held.add("UP");
    e.preventDefault();
  }
  if (e.code === "KeyS" || e.code === "ArrowDown") {
    held.add("DOWN");
    e.preventDefault();
  }
  if (e.code === "Enter" || e.code === "Space") {
    if (document.activeElement?.tagName === "INPUT") return;
    pressed.push("CONFIRM");
    e.preventDefault();
  }
  if (e.code === "KeyP" || e.code === "Escape") {
    if (document.activeElement?.tagName === "INPUT") return;
    pressed.push("PAUSE");
    e.preventDefault();
  }
  if (e.code === "KeyR") {
    if (document.activeElement?.tagName === "INPUT") return;
    pressed.push("RESTART");
    e.preventDefault();
  }
});

window.addEventListener("keyup", (e) => {
  if (e.code === "KeyW" || e.code === "ArrowUp") held.delete("UP");
  if (e.code === "KeyS" || e.code === "ArrowDown") held.delete("DOWN");
});

function startOffline() {
  if (ws) disconnect();
  mode = "offline";
  state = bootState();
  you = HUMAN_SEAT;
  seats = null;
  accum = 0;
  setControlsBusy(true);
  disconnectBtn.disabled = false;
  setStatus("Offline vs AI · seat P1");
}

function connect() {
  if (mode === "offline") stopOffline();
  if (ws) disconnect();
  const url = urlInput.value.trim() || "ws://127.0.0.1:8765";
  const room = roomInput.value.trim() || "demo";
  const name = nameInput.value.trim() || "phaser";
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
  ws.onerror = () => setStatus("Connection error — is the server running?");
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

function tickOffline(deltaSec) {
  let frameDt = Math.min(deltaSec, MAX_FRAME);
  accum += frameDt;
  let steps = 0;
  const edge = pressed.splice(0, pressed.length);
  while (accum >= DT && steps < MAX_STEPS) {
    const human = [];
    if (held.has("UP")) human.push("P1_UP");
    if (held.has("DOWN")) human.push("P1_DOWN");
    const allHeld = [...new Set([...human, ...aiHeld(state, AI_SEAT)])];
    step(state, allHeld, steps === 0 ? edge : []);
    accum -= DT;
    steps++;
  }
}

class PongScene extends Phaser.Scene {
  constructor() {
    super("pong");
  }

  create() {
    this.cameras.main.setBackgroundColor(COLORS.bg);

    this.centerGfx = this.add.graphics();
    this.drawCenterLine();

    this.p1 = this.add.rectangle(SIM.PADDLE_P1_X, PF_H / 2, SIM.PADDLE_WIDTH, SIM.PADDLE_HEIGHT, COLORS.pad);
    this.p2 = this.add.rectangle(SIM.PADDLE_P2_X, PF_H / 2, SIM.PADDLE_WIDTH, SIM.PADDLE_HEIGHT, COLORS.pad);
    this.p1Outline = this.add.rectangle(SIM.PADDLE_P1_X, PF_H / 2, SIM.PADDLE_WIDTH, SIM.PADDLE_HEIGHT)
      .setStrokeStyle(2, COLORS.you)
      .setFillStyle()
      .setVisible(false);
    this.p2Outline = this.add.rectangle(SIM.PADDLE_P2_X, PF_H / 2, SIM.PADDLE_WIDTH, SIM.PADDLE_HEIGHT)
      .setStrokeStyle(2, COLORS.you)
      .setFillStyle()
      .setVisible(false);

    this.ball = this.add.circle(PF_W / 2, PF_H / 2, SIM.BALL_RADIUS, COLORS.ball);

    const style = {
      fontFamily: '"IBM Plex Mono", monospace',
      fontSize: "32px",
      color: COLORS.text,
      fontStyle: "600",
    };
    this.score1 = this.add.text(300, 48, "0", style).setOrigin(0.5);
    this.score2 = this.add.text(500, 48, "0", style).setOrigin(0.5);

    this.title = this.add
      .text(400, 220, UI.title, { ...style, fontSize: "48px" })
      .setOrigin(0.5)
      .setVisible(false);
    this.subtitle = this.add
      .text(400, 300, UI.menu_subtitle, { ...style, fontSize: "16px", color: COLORS.text })
      .setOrigin(0.5)
      .setVisible(false);
    this.overlay = this.add
      .text(400, 300, "", { ...style, fontSize: "48px" })
      .setOrigin(0.5)
      .setVisible(false);
    this.overlayHint = this.add
      .text(400, 328, "", { ...style, fontSize: "16px" })
      .setOrigin(0.5)
      .setVisible(false);
    this.idleHint = this.add
      .text(400, 300, "Offline vs AI · or Connect", {
        ...style,
        fontSize: "16px",
        color: COLORS.hud,
      })
      .setOrigin(0.5);
    this.brand = this.add
      .text(400, 260, "MULTIPONG", { ...style, fontSize: "36px" })
      .setOrigin(0.5);
  }

  drawCenterLine() {
    const g = this.centerGfx;
    g.clear();
    g.fillStyle(COLORS.line, 1);
    const dash = 16;
    const gap = 12;
    const lw = 4;
    for (let y = 0; y < PF_H; y += dash + gap) {
      g.fillRect(PF_W / 2 - lw / 2, y, lw, dash);
    }
  }

  update(_t, deltaMs) {
    if (mode === "offline" && state) {
      tickOffline(deltaMs / 1000);
    } else if (mode === "online" && ws && ws.readyState === WebSocket.OPEN) {
      ws.send(
        JSON.stringify({
          type: "input",
          held: [...held],
          pressed: pressed.splice(0, pressed.length),
        })
      );
    }
    this.syncView();
  }

  syncView() {
    if (!state) {
      this.p1.setVisible(false);
      this.p2.setVisible(false);
      this.ball.setVisible(false);
      this.score1.setVisible(false);
      this.score2.setVisible(false);
      this.title.setVisible(false);
      this.subtitle.setVisible(false);
      this.overlay.setVisible(false);
      this.overlayHint.setVisible(false);
      this.p1Outline.setVisible(false);
      this.p2Outline.setVisible(false);
      this.brand.setVisible(true);
      this.idleHint.setVisible(true);
      return;
    }

    this.brand.setVisible(false);
    this.idleHint.setVisible(false);
    this.p1.setVisible(true).setPosition(SIM.PADDLE_P1_X, state.player1.y);
    this.p2.setVisible(true).setPosition(SIM.PADDLE_P2_X, state.player2.y);
    this.ball.setVisible(true).setPosition(state.ball.x, state.ball.y);
    this.score1.setVisible(true).setText(String(state.player1.score));
    this.score2.setVisible(true).setText(String(state.player2.score));

    this.p1Outline.setVisible(you === 1).setPosition(SIM.PADDLE_P1_X, state.player1.y);
    this.p2Outline.setVisible(you === 2).setPosition(SIM.PADDLE_P2_X, state.player2.y);

    const gameMode = state.mode;
    this.title.setVisible(false);
    this.subtitle.setVisible(false);
    this.overlay.setVisible(false);
    this.overlayHint.setVisible(false);

    if (gameMode === "MENU") {
      this.title.setVisible(true);
      this.subtitle.setVisible(true);
      this.subtitle.setText(
        mode === "offline"
          ? UI.menu_subtitle
          : seats && seats.players < 2
            ? "Waiting for opponent…"
            : UI.menu_subtitle
      );
    } else if (gameMode === "PAUSED") {
      this.overlay
        .setVisible(true)
        .setText(UI.paused_text)
        .setStyle({
          fontFamily: '"IBM Plex Mono", monospace',
          fontSize: "48px",
          color: COLORS.text,
          fontStyle: "600",
        })
        .setPosition(400, 300);
    } else if (gameMode === "GAME_OVER") {
      this.overlay
        .setVisible(true)
        .setText(state.winner === 1 ? UI.game_over_p1 : UI.game_over_p2)
        .setStyle({
          fontFamily: '"IBM Plex Mono", monospace',
          fontSize: "48px",
          color: COLORS.text,
          fontStyle: "600",
        })
        .setPosition(400, 276);
      this.overlayHint.setVisible(true).setText(UI.game_over_hint);
    } else if (gameMode === "POINT_SCORED") {
      this.overlay
        .setVisible(true)
        .setText("Point!")
        .setStyle({
          fontFamily: '"IBM Plex Mono", monospace',
          fontSize: "16px",
          color: COLORS.text,
          fontStyle: "600",
        })
        .setPosition(400, 300);
    }
  }
}

const game = new Phaser.Game({
  type: Phaser.AUTO,
  width: PF_W,
  height: PF_H,
  parent: "game-host",
  backgroundColor: COLORS.bg,
  // Explicitly no physics — simulation is canonical
  physics: undefined,
  scene: PongScene,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
});

if (params.get("offline") === "1") startOffline();
else if (params.get("autostart") === "1" || params.get("name")) connect();

window.MultiPongPhaser = {
  getState: () => state,
  getYou: () => you,
  getMode: () => mode,
  connect,
  disconnect,
  startOffline,
  game,
};
