-- Minimal WebSocket client for Love2D (LuaSocket TCP + RFC6455 framing).
-- Non-blocking: call :update() each frame. Text frames only.

local socket = require("socket")
local bit = bit or require("bit")

local Ws = {}
Ws.__index = Ws

local function bxor(a, b)
  if bit and bit.bxor then
    return bit.bxor(a, b)
  end
  -- Lua 5.3+/LuaJIT fallback via manual XOR if needed
  local r, p = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a % 2, b % 2
    if aa ~= bb then
      r = r + p
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    p = p * 2
  end
  return r
end

local function band(a, b)
  if bit and bit.band then
    return bit.band(a, b)
  end
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      r = r + p
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    p = p * 2
  end
  return r
end

local function rshift(a, n)
  if bit and bit.rshift then
    return bit.rshift(a, n)
  end
  return math.floor(a / (2 ^ n))
end

local function random_key()
  local bytes = {}
  for i = 1, 16 do
    bytes[i] = string.char(math.random(0, 255))
  end
  -- base64 of 16 random bytes
  local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local data = table.concat(bytes)
  local out = {}
  for i = 1, #data, 3 do
    local a = data:byte(i) or 0
    local b = data:byte(i + 1)
    local c = data:byte(i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local n1 = rshift(n, 18) % 64 + 1
    local n2 = rshift(n, 12) % 64 + 1
    local n3 = rshift(n, 6) % 64 + 1
    local n4 = n % 64 + 1
    out[#out + 1] = b64:sub(n1, n1)
    out[#out + 1] = b64:sub(n2, n2)
    out[#out + 1] = b and b64:sub(n3, n3) or "="
    out[#out + 1] = c and b64:sub(n4, n4) or "="
  end
  return table.concat(out)
end

local function parse_url(url)
  local host, port, path = url:match("^ws://([^:/]+):?(%d*)(/?.*)$")
  if not host then
    error("only ws:// URLs supported: " .. tostring(url))
  end
  if port == "" then
    port = "80"
  end
  if path == "" then
    path = "/"
  end
  return host, tonumber(port), path
end

local function mask_payload(payload)
  local m1 = math.random(0, 255)
  local m2 = math.random(0, 255)
  local m3 = math.random(0, 255)
  local m4 = math.random(0, 255)
  local mask = string.char(m1, m2, m3, m4)
  local masked = {}
  for i = 1, #payload do
    local b = payload:byte(i)
    local mk = mask:byte(((i - 1) % 4) + 1)
    masked[i] = string.char(bxor(b, mk))
  end
  return mask .. table.concat(masked)
end

local function encode_text_frame(text)
  local payload = text
  local len = #payload
  local header
  if len < 126 then
    header = string.char(0x81, 0x80 + len)
  elseif len < 65536 then
    header = string.char(0x81, 0x80 + 126, rshift(len, 8) % 256, len % 256)
  else
    error("payload too large")
  end
  return header .. mask_payload(payload)
end

local function encode_close_frame()
  return string.char(0x88, 0x80) .. mask_payload("")
end

function Ws.connect(url)
  local host, port, path = parse_url(url)
  local tcp, err = socket.tcp()
  if not tcp then
    return nil, err
  end
  tcp:settimeout(5)
  local ok, cerr = tcp:connect(host, port)
  if not ok then
    tcp:close()
    return nil, cerr
  end

  local key = random_key()
  local req = table.concat({
    "GET " .. path .. " HTTP/1.1\r\n",
    "Host: " .. host .. ":" .. port .. "\r\n",
    "Upgrade: websocket\r\n",
    "Connection: Upgrade\r\n",
    "Sec-WebSocket-Key: " .. key .. "\r\n",
    "Sec-WebSocket-Version: 13\r\n",
    "\r\n",
  })
  tcp:send(req)

  local buf = ""
  while not buf:find("\r\n\r\n") do
    local chunk, rerr, partial = tcp:receive(1)
    if chunk then
      buf = buf .. chunk
    elseif partial and #partial > 0 then
      buf = buf .. partial
    else
      tcp:close()
      return nil, rerr or "handshake timeout"
    end
    if #buf > 8192 then
      tcp:close()
      return nil, "handshake too large"
    end
  end
  if not buf:match("HTTP/1%.1 101") then
    tcp:close()
    return nil, "handshake failed: " .. buf:match("^[^\r\n]+") 
  end

  local leftover = buf:match("\r\n\r\n(.*)$") or ""
  tcp:settimeout(0)
  return setmetatable({
    tcp = tcp,
    buf = leftover,
    open = true,
    messages = {},
    error = nil,
  }, Ws)
end

function Ws:send(text)
  if not self.open then
    return false, "closed"
  end
  local ok, err = self.tcp:send(encode_text_frame(text))
  if not ok then
    self.open = false
    self.error = err
    return false, err
  end
  return true
end

local function try_parse_frame(self)
  if #self.buf < 2 then
    return false
  end
  local b1, b2 = self.buf:byte(1, 2)
  local opcode = band(b1, 0x0f)
  local masked = band(b2, 0x80) ~= 0
  local len = band(b2, 0x7f)
  local offset = 2
  if len == 126 then
    if #self.buf < 4 then
      return false
    end
    len = self.buf:byte(3) * 256 + self.buf:byte(4)
    offset = 4
  elseif len == 127 then
    -- 64-bit length not needed for MultiPong
    self.open = false
    self.error = "64-bit frames unsupported"
    return false
  end
  local mask_len = masked and 4 or 0
  if #self.buf < offset + mask_len + len then
    return false
  end
  local mask
  if masked then
    mask = self.buf:sub(offset + 1, offset + 4)
    offset = offset + 4
  end
  local payload = self.buf:sub(offset + 1, offset + len)
  self.buf = self.buf:sub(offset + len + 1)
  if masked then
    local parts = {}
    for i = 1, #payload do
      parts[i] = string.char(bxor(payload:byte(i), mask:byte(((i - 1) % 4) + 1)))
    end
    payload = table.concat(parts)
  end
  if opcode == 0x8 then
    self.open = false
    return true
  elseif opcode == 0x9 then
    -- ping → pong
    local frame = string.char(0x8a, 0x80 + #payload) .. mask_payload(payload)
    self.tcp:send(frame)
    return true
  elseif opcode == 0x1 or opcode == 0x0 then
    self.messages[#self.messages + 1] = payload
    return true
  end
  return true
end

function Ws:update()
  if not self.open then
    return
  end
  while true do
    local chunk, err, partial = self.tcp:receive(4096)
    if chunk then
      self.buf = self.buf .. chunk
    elseif partial and #partial > 0 then
      self.buf = self.buf .. partial
    elseif err == "timeout" then
      break
    else
      self.open = false
      self.error = err or "closed"
      break
    end
  end
  while try_parse_frame(self) do
  end
end

function Ws:poll()
  local out = self.messages
  self.messages = {}
  return out
end

function Ws:close()
  if self.open and self.tcp then
    pcall(function()
      self.tcp:send(encode_close_frame())
    end)
    self.open = false
  end
  if self.tcp then
    self.tcp:close()
    self.tcp = nil
  end
end

return Ws
