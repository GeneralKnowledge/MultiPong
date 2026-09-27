/**
 * Canonical Pong simulation (engine-independent).
 * Faithful port of reference/pong/pong_sim — browser + Node safe.
 */

import RAW from "./constants_data.js";

export const C = {
  PLAYFIELD_WIDTH: RAW.playfield.width,
  PLAYFIELD_HEIGHT: RAW.playfield.height,
  TICK_RATE: RAW.simulation.tick_rate,
  DT: 1 / RAW.simulation.tick_rate,
  BALL_RADIUS: RAW.ball.radius,
  BALL_SPEED_INITIAL: RAW.ball.speed_initial,
  BALL_SPEED_MAX: RAW.ball.speed_max,
  BALL_SPEED_INCREMENT: RAW.ball.speed_increment,
  SEPARATION_EPSILON: RAW.ball.separation_epsilon,
  PADDLE_WIDTH: RAW.paddle.width,
  PADDLE_HEIGHT: RAW.paddle.height,
  PADDLE_SPEED: RAW.paddle.speed,
  PADDLE_P1_X: RAW.paddle.p1_x,
  PADDLE_P2_X: RAW.paddle.p2_x,
  MAX_BOUNCE_ANGLE_DEG: RAW.paddle.max_bounce_angle_deg,
  PADDLE_Y_MIN: RAW.paddle.height / 2,
  PADDLE_Y_MAX: RAW.playfield.height - RAW.paddle.height / 2,
  SCORE_TO_WIN: RAW.scoring.score_to_win,
  POINT_PAUSE_DURATION: RAW.scoring.point_pause_duration,
  POSITION_EPSILON: RAW.comparison.position_epsilon,
  VELOCITY_EPSILON: RAW.comparison.velocity_epsilon,
  AI_DEADZONE: RAW.ai.deadzone,
  AI_KIND: RAW.ai.kind,
  AI_DEFAULT_HUMAN_SEAT: RAW.ai.default_human_seat,
  AI_DEFAULT_AI_SEAT: RAW.ai.default_ai_seat,
};

const MODE_MENU = "MENU";
const MODE_PLAYING = "PLAYING";
const MODE_POINT_SCORED = "POINT_SCORED";
const MODE_PAUSED = "PAUSED";
const MODE_GAME_OVER = "GAME_OVER";

const CANONICAL_HELD = new Set(["P1_UP", "P1_DOWN", "P2_UP", "P2_DOWN"]);
const CANONICAL_EDGE = new Set(["CONFIRM", "PAUSE", "RESTART"]);

export function bootState() {
  return {
    mode: MODE_MENU,
    tick: 0,
    elapsed_time: 0,
    point_pause_remaining: 0,
    mode_before_pause: null,
    ball: {
      x: C.PLAYFIELD_WIDTH / 2,
      y: C.PLAYFIELD_HEIGHT / 2,
      vx: 0,
      vy: 0,
      active: false,
    },
    player1: { y: C.PLAYFIELD_HEIGHT / 2, score: 0 },
    player2: { y: C.PLAYFIELD_HEIGHT / 2, score: 0 },
    serving_player: 1,
    winner: 0,
  };
}

export function deepMerge(base, overlay) {
  const out = structuredClone(base);
  for (const [key, value] of Object.entries(overlay)) {
    if (
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      out[key] &&
      typeof out[key] === "object" &&
      !Array.isArray(out[key])
    ) {
      out[key] = deepMerge(out[key], value);
    } else {
      out[key] = structuredClone(value);
    }
  }
  return out;
}

function clamp(value, lo, hi) {
  return value < lo ? lo : value > hi ? hi : value;
}

function resetBallForServe(state, servingPlayer) {
  const ball = state.ball;
  ball.x = C.PLAYFIELD_WIDTH / 2;
  ball.y = C.PLAYFIELD_HEIGHT / 2;
  ball.active = false;
  const speed = C.BALL_SPEED_INITIAL;
  if (servingPlayer === 1) {
    ball.vx = speed;
    ball.vy = 0;
  } else {
    ball.vx = -speed;
    ball.vy = 0;
  }
  state.serving_player = servingPlayer;
}

function startMatch(state) {
  state.player1.score = 0;
  state.player2.score = 0;
  state.player1.y = C.PLAYFIELD_HEIGHT / 2;
  state.player2.y = C.PLAYFIELD_HEIGHT / 2;
  state.winner = 0;
  state.tick = 0;
  state.elapsed_time = 0;
  state.point_pause_remaining = 0;
  state.mode_before_pause = null;
  resetBallForServe(state, 1);
  state.ball.active = true;
  state.mode = MODE_PLAYING;
  return ["ui_confirm"];
}

function fullReset(state) {
  const boot = bootState();
  for (const key of Object.keys(state)) delete state[key];
  Object.assign(state, boot);
}

function movePaddles(state, held) {
  let dy1 = 0;
  if (held.has("P1_UP")) dy1 -= C.PADDLE_SPEED * C.DT;
  if (held.has("P1_DOWN")) dy1 += C.PADDLE_SPEED * C.DT;
  state.player1.y = clamp(state.player1.y + dy1, C.PADDLE_Y_MIN, C.PADDLE_Y_MAX);

  let dy2 = 0;
  if (held.has("P2_UP")) dy2 -= C.PADDLE_SPEED * C.DT;
  if (held.has("P2_DOWN")) dy2 += C.PADDLE_SPEED * C.DT;
  state.player2.y = clamp(state.player2.y + dy2, C.PADDLE_Y_MIN, C.PADDLE_Y_MAX);
}

function wallCollisions(state, events) {
  const ball = state.ball;
  if (ball.y - C.BALL_RADIUS < 0) {
    ball.y = C.BALL_RADIUS;
    ball.vy = Math.abs(ball.vy);
    events.push("wall_hit");
  }
  if (ball.y + C.BALL_RADIUS > C.PLAYFIELD_HEIGHT) {
    ball.y = C.PLAYFIELD_HEIGHT - C.BALL_RADIUS;
    ball.vy = -Math.abs(ball.vy);
    events.push("wall_hit");
  }
}

function paddleOverlap(ball, paddleX, paddleY) {
  const left = paddleX - C.PADDLE_WIDTH / 2;
  const right = paddleX + C.PADDLE_WIDTH / 2;
  const top = paddleY - C.PADDLE_HEIGHT / 2;
  const bottom = paddleY + C.PADDLE_HEIGHT / 2;
  const closestX = clamp(ball.x, left, right);
  const closestY = clamp(ball.y, top, bottom);
  const dx = ball.x - closestX;
  const dy = ball.y - closestY;
  return dx * dx + dy * dy <= C.BALL_RADIUS * C.BALL_RADIUS;
}

function paddleHit(state, which, events) {
  const ball = state.ball;
  let paddleX;
  let paddleY;
  let direction;
  if (which === 1) {
    if (ball.vx >= 0) return;
    paddleX = C.PADDLE_P1_X;
    paddleY = state.player1.y;
    direction = 1;
  } else {
    if (ball.vx <= 0) return;
    paddleX = C.PADDLE_P2_X;
    paddleY = state.player2.y;
    direction = -1;
  }
  if (!paddleOverlap(ball, paddleX, paddleY)) return;

  events.push("paddle_hit");
  let offset = (ball.y - paddleY) / (C.PADDLE_HEIGHT / 2);
  offset = clamp(offset, -1, 1);
  const oldSpeed = Math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy);
  const newSpeed = Math.min(oldSpeed + C.BALL_SPEED_INCREMENT, C.BALL_SPEED_MAX);
  const angleRad = (offset * C.MAX_BOUNCE_ANGLE_DEG * Math.PI) / 180;
  ball.vx = newSpeed * Math.cos(angleRad) * direction;
  ball.vy = newSpeed * Math.sin(angleRad);
  if (which === 1) {
    ball.x = paddleX + C.PADDLE_WIDTH / 2 + C.BALL_RADIUS + C.SEPARATION_EPSILON;
  } else {
    ball.x = paddleX - C.PADDLE_WIDTH / 2 - C.BALL_RADIUS - C.SEPARATION_EPSILON;
  }
}

function handlePointScored(state, scoredBy, events) {
  if (state.player1.score >= C.SCORE_TO_WIN || state.player2.score >= C.SCORE_TO_WIN) {
    state.mode = MODE_GAME_OVER;
    state.winner = state.player1.score >= C.SCORE_TO_WIN ? 1 : 2;
    state.ball.active = false;
    events.push("game_over");
    return;
  }
  state.mode = MODE_POINT_SCORED;
  state.point_pause_remaining = C.POINT_PAUSE_DURATION;
  resetBallForServe(state, scoredBy === 1 ? 2 : 1);
}

function checkScoring(state, events) {
  const ball = state.ball;
  if (ball.x + C.BALL_RADIUS < 0) {
    state.player2.score += 1;
    events.push("score");
    handlePointScored(state, 2, events);
    return;
  }
  if (ball.x - C.BALL_RADIUS > C.PLAYFIELD_WIDTH) {
    state.player1.score += 1;
    events.push("score");
    handlePointScored(state, 1, events);
  }
}

function playingPhysics(state, held, events) {
  movePaddles(state, held);
  const ball = state.ball;
  if (ball.active) {
    ball.x += ball.vx * C.DT;
    ball.y += ball.vy * C.DT;
    wallCollisions(state, events);
    paddleHit(state, 1, events);
    paddleHit(state, 2, events);
    checkScoring(state, events);
  }
  if (state.mode === MODE_PLAYING || state.mode === MODE_POINT_SCORED) {
    state.tick += 1;
    state.elapsed_time = state.tick * C.DT;
  }
}

/** Advance one fixed tick. Mutates state. Returns events. */
export function step(state, held = [], pressed = []) {
  const heldSet = new Set([...held].filter((a) => CANONICAL_HELD.has(a)));
  const pressedSet = new Set([...pressed].filter((a) => CANONICAL_EDGE.has(a)));
  const events = [];
  const mode = state.mode;

  if (mode === MODE_MENU) {
    if (pressedSet.has("RESTART")) {
      fullReset(state);
      return events;
    }
    if (pressedSet.has("CONFIRM")) {
      events.push(...startMatch(state));
    }
    return events;
  }

  if (mode === MODE_PLAYING) {
    if (pressedSet.has("RESTART")) {
      fullReset(state);
      return events;
    }
    if (pressedSet.has("PAUSE")) {
      state.mode_before_pause = MODE_PLAYING;
      state.mode = MODE_PAUSED;
      return events;
    }
    playingPhysics(state, heldSet, events);
    return events;
  }

  if (mode === MODE_POINT_SCORED) {
    if (pressedSet.has("RESTART")) {
      fullReset(state);
      return events;
    }
    if (pressedSet.has("PAUSE")) {
      state.mode_before_pause = MODE_POINT_SCORED;
      state.mode = MODE_PAUSED;
      return events;
    }
    movePaddles(state, heldSet);
    state.point_pause_remaining -= C.DT;
    if (state.point_pause_remaining <= 0) {
      state.point_pause_remaining = 0;
      state.mode = MODE_PLAYING;
      state.ball.active = true;
    }
    state.tick += 1;
    state.elapsed_time = state.tick * C.DT;
    return events;
  }

  if (mode === MODE_PAUSED) {
    if (pressedSet.has("RESTART")) {
      fullReset(state);
      return events;
    }
    if (pressedSet.has("PAUSE")) {
      state.mode = state.mode_before_pause || MODE_PLAYING;
      state.mode_before_pause = null;
    }
    return events;
  }

  if (mode === MODE_GAME_OVER) {
    if (pressedSet.has("CONFIRM")) {
      events.push("ui_confirm");
      fullReset(state);
      return events;
    }
    if (pressedSet.has("RESTART")) {
      fullReset(state);
    }
  }

  return events;
}

/**
 * Canonical offline AI (specs/pong/AI_SPEC.md).
 * Returns held action names for the given seat (1 or 2).
 */
export function aiHeld(state, seat = C.AI_DEFAULT_AI_SEAT) {
  if (state.mode !== MODE_PLAYING && state.mode !== MODE_POINT_SCORED) {
    return [];
  }
  const paddleY = seat === 1 ? state.player1.y : state.player2.y;
  const ball = state.ball;
  const approaching =
    (seat === 1 && ball.vx < 0) || (seat === 2 && ball.vx > 0);
  let targetY;
  if (ball.active && approaching) {
    targetY = ball.y;
  } else {
    targetY = C.PLAYFIELD_HEIGHT / 2;
  }
  const delta = targetY - paddleY;
  const up = seat === 1 ? "P1_UP" : "P2_UP";
  const down = seat === 1 ? "P1_DOWN" : "P2_DOWN";
  if (delta < -C.AI_DEADZONE) return [up];
  if (delta > C.AI_DEADZONE) return [down];
  return [];
}
