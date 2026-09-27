-- MultiPong Love2D client — dual-mode.
-- Offline: local pong_sim + canonical simple_track AI (seat 2).
-- Online: authoritative WebSocket server (seat-relative input).
--
-- Usage:
--   love examples/lua -- --offline
--   love examples/lua -- --name love1
--   love examples/lua -- --test   (run specs/pong/tests, then quit)

local json = require("json")
local sim = require("pong_sim")
local Ws = require("ws")

local UI = {
  title = "PONG",
  menu_subtitle = "Press Enter",
  paused_text = "PAUSED",
  game_over_p1 = "PLAYER 1 WINS",
  game_over_p2 = "PLAYER 2 WINS",
  game_over_hint = "Press Enter",
  text_color = { 242 / 255, 245 / 255, 248 / 255 },
  title_font_size = 48,
  subtitle_font_size = 16,
  title_center = { 400, 220 },
  subtitle_center = { 400, 300 },
}

local BG = { 11 / 255, 14 / 255, 20 / 255 }
local LINE = { 42 / 255, 51 / 255, 68 / 255 }
local BALL_COLOR = { 242 / 255, 245 / 255, 248 / 255 }
local PAD_COLOR = { 232 / 255, 238 / 255, 245 / 255 }
local SCORE_COLOR = { 242 / 255, 245 / 255, 248 / 255 }
local YOU_OUTLINE = { 127 / 255, 208 / 255, 197 / 255 }
local HUD = { 139 / 255, 149 / 255, 168 / 255 }
local LINE_W = 4
local DASH = 16
local GAP = 12

local cfg = {
  offline = false,
  test = false,
  url = "ws://127.0.0.1:8765",
  room = "demo",
  name = "love2d",
}

local mode = "idle" -- idle | offline | online
local state = nil
local you = nil
local seats = nil
local status = "Choose Offline (O) or Connect (C)"
local held = {}
local pressed = {}
local accum = 0
local ws = nil
local fonts = {}

local function parse_args(args)
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--offline" then
      cfg.offline = true
    elseif a == "--online" then
      cfg.offline = false
    elseif a == "--test" then
      cfg.test = true
    elseif a == "--url" and args[i + 1] then
      i = i + 1
      cfg.url = args[i]
    elseif a == "--room" and args[i + 1] then
      i = i + 1
      cfg.room = args[i]
    elseif a == "--name" and args[i + 1] then
      i = i + 1
      cfg.name = args[i]
    elseif a:match("^%-%-url=") then
      cfg.url = a:match("^%-%-url=(.+)$")
    elseif a:match("^%-%-room=") then
      cfg.room = a:match("^%-%-room=(.+)$")
    elseif a:match("^%-%-name=") then
      cfg.name = a:match("^%-%-name=(.+)$")
    end
    i = i + 1
  end
end

local function start_offline()
  if ws then
    ws:close()
    ws = nil
  end
  mode = "offline"
  state = sim.boot_state()
  you = sim.AI_DEFAULT_HUMAN_SEAT
  seats = nil
  accum = 0
  status = "Offline vs AI · seat P1"
  love.window.setTitle("MultiPong — offline vs AI")
end

local function start_online()
  if ws then
    ws:close()
    ws = nil
  end
  mode = "online"
  state = nil
  you = nil
  seats = nil
  status = "Connecting…"
  love.window.setTitle("MultiPong — " .. cfg.name)
  local client, err = Ws.connect(cfg.url)
  if not client then
    status = "Connection failed: " .. tostring(err)
    mode = "idle"
    return
  end
  ws = client
  ws:send(json.encode({ type = "join", room = cfg.room, name = cfg.name }))
  status = "Connected · room " .. cfg.room
end

local function stop_session()
  if ws then
    ws:close()
    ws = nil
  end
  mode = "idle"
  state = nil
  you = nil
  seats = nil
  accum = 0
  status = "Choose Offline (O) or Connect (C)"
  love.window.setTitle("MultiPong — Love2D")
end

local function poll_held()
  held = {}
  if love.keyboard.isDown("w", "up") then
    held[#held + 1] = "UP"
  end
  if love.keyboard.isDown("s", "down") then
    held[#held + 1] = "DOWN"
  end
end

local function draw_text_centered(text, x, y, font, color)
  love.graphics.setFont(font)
  love.graphics.setColor(color)
  local w = font:getWidth(text)
  local h = font:getHeight()
  love.graphics.print(text, x - w / 2, y - h / 2)
end

local function draw_paddle(cx, cy, highlight)
  local w, h = sim.PADDLE_WIDTH, sim.PADDLE_HEIGHT
  love.graphics.setColor(PAD_COLOR)
  love.graphics.rectangle("fill", cx - w / 2, cy - h / 2, w, h)
  if highlight then
    love.graphics.setColor(YOU_OUTLINE)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - w / 2 + 0.5, cy - h / 2 + 0.5, w - 1, h - 1)
  end
end

local function draw_game()
  local W, H = sim.PLAYFIELD_WIDTH, sim.PLAYFIELD_HEIGHT
  love.graphics.clear(BG[1], BG[2], BG[3])

  love.graphics.setColor(LINE)
  local y = 0
  while y < H do
    love.graphics.rectangle("fill", W / 2 - LINE_W / 2, y, LINE_W, DASH)
    y = y + DASH + GAP
  end

  if state then
    draw_paddle(sim.PADDLE_P1_X, state.player1.y, you == 1)
    draw_paddle(sim.PADDLE_P2_X, state.player2.y, you == 2)
    love.graphics.setColor(BALL_COLOR)
    love.graphics.circle("fill", state.ball.x, state.ball.y, sim.BALL_RADIUS)

    draw_text_centered(
      tostring(state.player1.score),
      300,
      48,
      fonts.score,
      SCORE_COLOR
    )
    draw_text_centered(
      tostring(state.player2.score),
      500,
      48,
      fonts.score,
      SCORE_COLOR
    )

    local game_mode = state.mode
    if game_mode == "MENU" then
      draw_text_centered(UI.title, UI.title_center[1], UI.title_center[2], fonts.title, UI.text_color)
      local sub = UI.menu_subtitle
      if mode == "online" and seats and (seats.players or 0) < 2 then
        sub = "Waiting for opponent…"
      end
      draw_text_centered(
        sub,
        UI.subtitle_center[1],
        UI.subtitle_center[2],
        fonts.sub,
        UI.text_color
      )
    elseif game_mode == "PAUSED" then
      draw_text_centered(UI.paused_text, W / 2, H / 2, fonts.title, UI.text_color)
    elseif game_mode == "GAME_OVER" then
      local msg = state.winner == 1 and UI.game_over_p1 or UI.game_over_p2
      draw_text_centered(msg, W / 2, H / 2 - 24, fonts.title, UI.text_color)
      draw_text_centered(UI.game_over_hint, W / 2, H / 2 + 28, fonts.sub, UI.text_color)
    elseif game_mode == "POINT_SCORED" then
      draw_text_centered("Point!", W / 2, H / 2, fonts.sub, UI.text_color)
    end
  else
    draw_text_centered("MULTIPONG", W / 2, H / 2 - 20, fonts.title, UI.text_color)
    draw_text_centered("O offline · C connect · Esc quit", W / 2, H / 2 + 24, fonts.sub, HUD)
  end

  local seat = you and ("P" .. you) or "—"
  local line = string.format(
    "%s   seat %s   W/S or ↑/↓ · Enter · P · R",
    status,
    seat
  )
  love.graphics.setFont(fonts.hud)
  love.graphics.setColor(HUD)
  love.graphics.print(line, 12, H - 22)
end

local function tick_offline(dt)
  if dt > sim.MAX_FRAME_TIME then
    dt = sim.MAX_FRAME_TIME
  end
  accum = accum + dt
  local edge = pressed
  pressed = {}
  local steps = 0
  while accum >= sim.DT and steps < sim.MAX_STEPS_PER_FRAME do
    local human = {}
    for _, a in ipairs(held) do
      if a == "UP" then
        human[#human + 1] = "P1_UP"
      elseif a == "DOWN" then
        human[#human + 1] = "P1_DOWN"
      end
    end
    local ai = sim.ai_held(state, sim.AI_DEFAULT_AI_SEAT)
    local all = {}
    local seen = {}
    for _, a in ipairs(human) do
      if not seen[a] then
        seen[a] = true
        all[#all + 1] = a
      end
    end
    for _, a in ipairs(ai) do
      if not seen[a] then
        seen[a] = true
        all[#all + 1] = a
      end
    end
    sim.step(state, all, steps == 0 and edge or {})
    accum = accum - sim.DT
    steps = steps + 1
  end
end

local function handle_online_messages()
  if not ws then
    return
  end
  for _, raw in ipairs(ws:poll()) do
    local ok, msg = pcall(json.decode, raw)
    if ok and type(msg) == "table" then
      if msg.type == "welcome" then
        you = msg.player
        status = string.format("Connected · room %s · you are P%d", msg.room, you)
      elseif msg.type == "state" then
        state = msg.state
        if msg.you then
          you = msg.you
        end
      elseif msg.type == "room" then
        seats = msg
        local n = msg.players or 0
        if n < 2 then
          status = string.format("Connected · waiting for opponent (%d/2)", n)
        else
          status = string.format("Connected · room %s · 2/2", msg.room)
        end
      elseif msg.type == "error" then
        status = "Error: " .. tostring(msg.message)
      end
    end
  end
end

function love.load(args)
  math.randomseed(os.time())
  parse_args(args or {})

  if cfg.test then
    package.path = love.filesystem.getSource() .. "/?.lua;" .. package.path
    local ok, code = pcall(function()
      return require("run_tests").run()
    end)
    if not ok then
      print("TEST RUNNER ERROR: " .. tostring(code))
      love.event.quit()
      os.exit(1)
    end
    love.event.quit()
    os.exit(code or 0)
  end

  fonts.score = love.graphics.newFont(32)
  fonts.title = love.graphics.newFont(UI.title_font_size)
  fonts.sub = love.graphics.newFont(UI.subtitle_font_size)
  fonts.hud = love.graphics.newFont(14)

  if cfg.offline then
    start_offline()
  else
    -- Default: idle until O/C, unless --name implies online intent with server
    -- Match other clients: without --offline, try online connect.
    start_online()
  end
end

function love.update(dt)
  if cfg.test then
    return
  end
  poll_held()
  if mode == "offline" and state then
    tick_offline(dt)
  elseif mode == "online" and ws then
    ws:update()
    if not ws.open then
      status = "Disconnected" .. (ws.error and (": " .. ws.error) or "")
      mode = "idle"
      ws = nil
      return
    end
    handle_online_messages()
    local edge = pressed
    pressed = {}
    ws:send(json.encode({ type = "input", held = held, pressed = edge }))
  end
end

function love.keypressed(key)
  if cfg.test then
    return
  end
  if key == "return" or key == "space" then
    pressed[#pressed + 1] = "CONFIRM"
  elseif key == "p" or key == "escape" then
    if key == "escape" and mode == "idle" then
      love.event.quit()
      return
    end
    if key == "escape" and (mode == "offline" or mode == "online") then
      stop_session()
      return
    end
    pressed[#pressed + 1] = "PAUSE"
  elseif key == "r" then
    pressed[#pressed + 1] = "RESTART"
  elseif key == "o" and mode == "idle" then
    start_offline()
  elseif key == "c" and mode == "idle" then
    start_online()
  end
end

function love.draw()
  if cfg.test then
    return
  end
  draw_game()
end

function love.quit()
  if ws then
    ws:close()
  end
end
