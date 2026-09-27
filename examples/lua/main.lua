-- Love2D MultiPong example (protocol-focused).
-- Love does not bundle WebSockets; this demo runs a local *offline echo* of the
-- message shapes, and prints the exact JSON you should send once you add a WS client.
--
-- Production path: luarocks / vendored websocket + dkjson, then replace
-- send_json() with client:send(...).

local URL = "ws://127.0.0.1:8765"
local ROOM = "demo"
local NAME = "love2d"

local function encode_array(items)
  local parts = {}
  for i, v in ipairs(items) do
    parts[i] = string.format("%q", v)
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function join_msg()
  return string.format(
    '{"type":"join","room":%q,"name":%q}',
    ROOM,
    NAME
  )
end

local function input_msg(held, pressed)
  return string.format(
    '{"type":"input","held":%s,"pressed":%s}',
    encode_array(held),
    encode_array(pressed)
  )
end

local held, pressed = {}, {}
local log = "Connect a websocket client to " .. URL .. "\n" .. join_msg()

function love.load()
  love.window.setMode(800, 600)
  love.window.setTitle("MultiPong Love2D example")
end

function love.update()
  held = {}
  if love.keyboard.isDown("w", "up") then held[#held + 1] = "UP" end
  if love.keyboard.isDown("s", "down") then held[#held + 1] = "DOWN" end
end

function love.keypressed(key)
  if key == "return" or key == "space" then
    pressed[#pressed + 1] = "CONFIRM"
  elseif key == "p" or key == "escape" then
    pressed[#pressed + 1] = "PAUSE"
  elseif key == "r" then
    pressed[#pressed + 1] = "RESTART"
  elseif key == "i" then
    -- Preview the input frame that would be sent
    log = input_msg(held, pressed)
    pressed = {}
  end
end

function love.draw()
  love.graphics.clear(11 / 255, 14 / 255, 20 / 255)
  love.graphics.setColor(0.95, 0.96, 0.97)
  love.graphics.print("MultiPong Love2D — press I to preview input JSON", 40, 40)
  love.graphics.printf(log, 40, 80, 720)
  love.graphics.print("held: " .. table.concat(held, ","), 40, 560)
end
