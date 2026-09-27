-- Canonical Pong simulation (Lua port of reference/js/pong_sim.js).
-- Engine-independent: no love.* calls. See specs/pong/GAME_SPEC.md + AI_SPEC.md.

local M = {}

M.PLAYFIELD_WIDTH = 800
M.PLAYFIELD_HEIGHT = 600
M.TICK_RATE = 60
M.DT = 1 / 60
M.BALL_RADIUS = 8
M.BALL_SPEED_INITIAL = 300
M.BALL_SPEED_MAX = 600
M.BALL_SPEED_INCREMENT = 25
M.SEPARATION_EPSILON = 0.01
M.PADDLE_WIDTH = 12
M.PADDLE_HEIGHT = 80
M.PADDLE_SPEED = 400
M.PADDLE_P1_X = 40
M.PADDLE_P2_X = 760
M.MAX_BOUNCE_ANGLE_DEG = 50
M.PADDLE_Y_MIN = M.PADDLE_HEIGHT / 2
M.PADDLE_Y_MAX = M.PLAYFIELD_HEIGHT - M.PADDLE_HEIGHT / 2
M.SCORE_TO_WIN = 11
M.POINT_PAUSE_DURATION = 1.0
M.AI_DEADZONE = 12
M.AI_DEFAULT_HUMAN_SEAT = 1
M.AI_DEFAULT_AI_SEAT = 2
M.MAX_STEPS_PER_FRAME = 5
M.MAX_FRAME_TIME = 0.25

local MODE_MENU = "MENU"
local MODE_PLAYING = "PLAYING"
local MODE_POINT_SCORED = "POINT_SCORED"
local MODE_PAUSED = "PAUSED"
local MODE_GAME_OVER = "GAME_OVER"

local CANONICAL_HELD = {
  P1_UP = true,
  P1_DOWN = true,
  P2_UP = true,
  P2_DOWN = true,
}
local CANONICAL_EDGE = {
  CONFIRM = true,
  PAUSE = true,
  RESTART = true,
}

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function held_set(held)
  local out = {}
  for _, a in ipairs(held or {}) do
    if CANONICAL_HELD[a] then
      out[a] = true
    end
  end
  return out
end

local function pressed_set(pressed)
  local out = {}
  for _, a in ipairs(pressed or {}) do
    if CANONICAL_EDGE[a] then
      out[a] = true
    end
  end
  return out
end

function M.boot_state()
  return {
    mode = MODE_MENU,
    tick = 0,
    elapsed_time = 0,
    point_pause_remaining = 0,
    mode_before_pause = nil,
    ball = {
      x = M.PLAYFIELD_WIDTH / 2,
      y = M.PLAYFIELD_HEIGHT / 2,
      vx = 0,
      vy = 0,
      active = false,
    },
    player1 = { y = M.PLAYFIELD_HEIGHT / 2, score = 0 },
    player2 = { y = M.PLAYFIELD_HEIGHT / 2, score = 0 },
    serving_player = 1,
    winner = 0,
  }
end

local function is_object_table(t)
  if type(t) ~= "table" then
    return false
  end
  for k in pairs(t) do
    if type(k) == "string" then
      return true
    end
  end
  return next(t) == nil
end

local function deep_merge(base, overlay)
  for key, value in pairs(overlay) do
    if type(value) == "table" and type(base[key]) == "table" and is_object_table(value) then
      deep_merge(base[key], value)
    else
      base[key] = value
    end
  end
  return base
end

function M.deep_merge(base, overlay)
  return deep_merge(base, overlay)
end

local function reset_ball_for_serve(state, serving_player)
  local ball = state.ball
  ball.x = M.PLAYFIELD_WIDTH / 2
  ball.y = M.PLAYFIELD_HEIGHT / 2
  ball.active = false
  local speed = M.BALL_SPEED_INITIAL
  if serving_player == 1 then
    ball.vx = speed
    ball.vy = 0
  else
    ball.vx = -speed
    ball.vy = 0
  end
  state.serving_player = serving_player
end

local function start_match(state)
  state.player1.score = 0
  state.player2.score = 0
  state.player1.y = M.PLAYFIELD_HEIGHT / 2
  state.player2.y = M.PLAYFIELD_HEIGHT / 2
  state.winner = 0
  state.tick = 0
  state.elapsed_time = 0
  state.point_pause_remaining = 0
  state.mode_before_pause = nil
  reset_ball_for_serve(state, 1)
  state.ball.active = true
  state.mode = MODE_PLAYING
  return { "ui_confirm" }
end

local function full_reset(state)
  local boot = M.boot_state()
  for k in pairs(state) do
    state[k] = nil
  end
  for k, v in pairs(boot) do
    state[k] = v
  end
end

local function move_paddles(state, held)
  local dy1 = 0
  if held.P1_UP then
    dy1 = dy1 - M.PADDLE_SPEED * M.DT
  end
  if held.P1_DOWN then
    dy1 = dy1 + M.PADDLE_SPEED * M.DT
  end
  state.player1.y = clamp(state.player1.y + dy1, M.PADDLE_Y_MIN, M.PADDLE_Y_MAX)

  local dy2 = 0
  if held.P2_UP then
    dy2 = dy2 - M.PADDLE_SPEED * M.DT
  end
  if held.P2_DOWN then
    dy2 = dy2 + M.PADDLE_SPEED * M.DT
  end
  state.player2.y = clamp(state.player2.y + dy2, M.PADDLE_Y_MIN, M.PADDLE_Y_MAX)
end

local function wall_collisions(state, events)
  local ball = state.ball
  if ball.y - M.BALL_RADIUS < 0 then
    ball.y = M.BALL_RADIUS
    ball.vy = math.abs(ball.vy)
    events[#events + 1] = "wall_hit"
  end
  if ball.y + M.BALL_RADIUS > M.PLAYFIELD_HEIGHT then
    ball.y = M.PLAYFIELD_HEIGHT - M.BALL_RADIUS
    ball.vy = -math.abs(ball.vy)
    events[#events + 1] = "wall_hit"
  end
end

local function paddle_overlap(ball, paddle_x, paddle_y)
  local left = paddle_x - M.PADDLE_WIDTH / 2
  local right = paddle_x + M.PADDLE_WIDTH / 2
  local top = paddle_y - M.PADDLE_HEIGHT / 2
  local bottom = paddle_y + M.PADDLE_HEIGHT / 2
  local closest_x = clamp(ball.x, left, right)
  local closest_y = clamp(ball.y, top, bottom)
  local dx = ball.x - closest_x
  local dy = ball.y - closest_y
  return dx * dx + dy * dy <= M.BALL_RADIUS * M.BALL_RADIUS
end

local function paddle_hit(state, which, events)
  local ball = state.ball
  local paddle_x, paddle_y, direction
  if which == 1 then
    if ball.vx >= 0 then
      return
    end
    paddle_x = M.PADDLE_P1_X
    paddle_y = state.player1.y
    direction = 1
  else
    if ball.vx <= 0 then
      return
    end
    paddle_x = M.PADDLE_P2_X
    paddle_y = state.player2.y
    direction = -1
  end
  if not paddle_overlap(ball, paddle_x, paddle_y) then
    return
  end

  events[#events + 1] = "paddle_hit"
  local offset = (ball.y - paddle_y) / (M.PADDLE_HEIGHT / 2)
  offset = clamp(offset, -1, 1)
  local old_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
  local new_speed = math.min(old_speed + M.BALL_SPEED_INCREMENT, M.BALL_SPEED_MAX)
  local angle_rad = (offset * M.MAX_BOUNCE_ANGLE_DEG * math.pi) / 180
  ball.vx = new_speed * math.cos(angle_rad) * direction
  ball.vy = new_speed * math.sin(angle_rad)
  if which == 1 then
    ball.x = paddle_x + M.PADDLE_WIDTH / 2 + M.BALL_RADIUS + M.SEPARATION_EPSILON
  else
    ball.x = paddle_x - M.PADDLE_WIDTH / 2 - M.BALL_RADIUS - M.SEPARATION_EPSILON
  end
end

local function handle_point_scored(state, scored_by, events)
  if state.player1.score >= M.SCORE_TO_WIN or state.player2.score >= M.SCORE_TO_WIN then
    state.mode = MODE_GAME_OVER
    state.winner = state.player1.score >= M.SCORE_TO_WIN and 1 or 2
    state.ball.active = false
    events[#events + 1] = "game_over"
    return
  end
  state.mode = MODE_POINT_SCORED
  state.point_pause_remaining = M.POINT_PAUSE_DURATION
  reset_ball_for_serve(state, scored_by == 1 and 2 or 1)
end

local function check_scoring(state, events)
  local ball = state.ball
  if ball.x + M.BALL_RADIUS < 0 then
    state.player2.score = state.player2.score + 1
    events[#events + 1] = "score"
    handle_point_scored(state, 2, events)
    return
  end
  if ball.x - M.BALL_RADIUS > M.PLAYFIELD_WIDTH then
    state.player1.score = state.player1.score + 1
    events[#events + 1] = "score"
    handle_point_scored(state, 1, events)
  end
end

local function playing_physics(state, held, events)
  move_paddles(state, held)
  local ball = state.ball
  if ball.active then
    ball.x = ball.x + ball.vx * M.DT
    ball.y = ball.y + ball.vy * M.DT
    wall_collisions(state, events)
    paddle_hit(state, 1, events)
    paddle_hit(state, 2, events)
    check_scoring(state, events)
  end
  if state.mode == MODE_PLAYING or state.mode == MODE_POINT_SCORED then
    state.tick = state.tick + 1
    state.elapsed_time = state.tick * M.DT
  end
end

--- Advance one fixed tick. Mutates state. Returns event name list.
function M.step(state, held, pressed)
  local h = held_set(held)
  local p = pressed_set(pressed)
  local events = {}
  local mode = state.mode

  if mode == MODE_MENU then
    if p.RESTART then
      full_reset(state)
      return events
    end
    if p.CONFIRM then
      local started = start_match(state)
      for _, e in ipairs(started) do
        events[#events + 1] = e
      end
    end
    return events
  end

  if mode == MODE_PLAYING then
    if p.RESTART then
      full_reset(state)
      return events
    end
    if p.PAUSE then
      state.mode_before_pause = MODE_PLAYING
      state.mode = MODE_PAUSED
      return events
    end
    playing_physics(state, h, events)
    return events
  end

  if mode == MODE_POINT_SCORED then
    if p.RESTART then
      full_reset(state)
      return events
    end
    if p.PAUSE then
      state.mode_before_pause = MODE_POINT_SCORED
      state.mode = MODE_PAUSED
      return events
    end
    move_paddles(state, h)
    state.point_pause_remaining = state.point_pause_remaining - M.DT
    if state.point_pause_remaining <= 0 then
      state.point_pause_remaining = 0
      state.mode = MODE_PLAYING
      state.ball.active = true
    end
    state.tick = state.tick + 1
    state.elapsed_time = state.tick * M.DT
    return events
  end

  if mode == MODE_PAUSED then
    if p.RESTART then
      full_reset(state)
      return events
    end
    if p.PAUSE then
      state.mode = state.mode_before_pause or MODE_PLAYING
      state.mode_before_pause = nil
    end
    return events
  end

  if mode == MODE_GAME_OVER then
    if p.CONFIRM then
      events[#events + 1] = "ui_confirm"
      full_reset(state)
      return events
    end
    if p.RESTART then
      full_reset(state)
    end
  end

  return events
end

--- Canonical offline AI (specs/pong/AI_SPEC.md).
function M.ai_held(state, seat)
  seat = seat or M.AI_DEFAULT_AI_SEAT
  if state.mode ~= MODE_PLAYING and state.mode ~= MODE_POINT_SCORED then
    return {}
  end
  local paddle_y = seat == 1 and state.player1.y or state.player2.y
  local ball = state.ball
  local approaching = (seat == 1 and ball.vx < 0) or (seat == 2 and ball.vx > 0)
  local target_y
  if ball.active and approaching then
    target_y = ball.y
  else
    target_y = M.PLAYFIELD_HEIGHT / 2
  end
  local delta = target_y - paddle_y
  local up = seat == 1 and "P1_UP" or "P2_UP"
  local down = seat == 1 and "P1_DOWN" or "P2_DOWN"
  if delta < -M.AI_DEADZONE then
    return { up }
  end
  if delta > M.AI_DEADZONE then
    return { down }
  end
  return {}
end

return M
