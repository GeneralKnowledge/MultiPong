-- Minimal JSON encode/decode for MultiPong messages (no external deps).
local json = {}

local function esc(s)
  return s:gsub('[\\"\n\r\t]', {
    ["\\"] = "\\\\",
    ['"'] = '\\"',
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
  })
end

function json.encode(val)
  local t = type(val)
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return val and "true" or "false"
  elseif t == "number" then
    if val ~= val or val == math.huge or val == -math.huge then
      return "null"
    end
    return string.format("%.17g", val)
  elseif t == "string" then
    return '"' .. esc(val) .. '"'
  elseif t == "table" then
    local is_array = true
    local n = 0
    for k, _ in pairs(val) do
      n = n + 1
      if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
        is_array = false
        break
      end
    end
    if is_array then
      -- dense array 1..#val
      local parts = {}
      for i = 1, #val do
        parts[i] = json.encode(val[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(val) do
        if type(k) == "string" then
          parts[#parts + 1] = '"' .. esc(k) .. '":' .. json.encode(v)
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  error("cannot encode " .. t)
end

local function skip(str, i)
  while true do
    local c = str:sub(i, i)
    if c == " " or c == "\n" or c == "\r" or c == "\t" then
      i = i + 1
    else
      return i
    end
  end
end

local parse_value

local function parse_string(str, i)
  i = i + 1
  local out = {}
  while i <= #str do
    local c = str:sub(i, i)
    if c == '"' then
      return table.concat(out), i + 1
    elseif c == "\\" then
      local n = str:sub(i + 1, i + 1)
      local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
      if n == "u" then
        local hex = str:sub(i + 2, i + 5)
        out[#out + 1] = utf8.char(tonumber(hex, 16) or 0)
        i = i + 6
      else
        out[#out + 1] = map[n] or n
        i = i + 2
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  error("unterminated string")
end

local function parse_number(str, i)
  local j = i
  while str:sub(j, j):match("[%d%+%-%.eE]") do
    j = j + 1
  end
  return tonumber(str:sub(i, j - 1)), j
end

local function parse_array(str, i)
  i = skip(str, i + 1)
  local arr = {}
  if str:sub(i, i) == "]" then
    return arr, i + 1
  end
  while true do
    local v
    v, i = parse_value(str, i)
    arr[#arr + 1] = v
    i = skip(str, i)
    local c = str:sub(i, i)
    if c == "]" then
      return arr, i + 1
    elseif c == "," then
      i = skip(str, i + 1)
    else
      error("bad array at " .. i)
    end
  end
end

local function parse_object(str, i)
  i = skip(str, i + 1)
  local obj = {}
  if str:sub(i, i) == "}" then
    return obj, i + 1
  end
  while true do
    i = skip(str, i)
    if str:sub(i, i) ~= '"' then
      error("object key expected at " .. i)
    end
    local key
    key, i = parse_string(str, i)
    i = skip(str, i)
    if str:sub(i, i) ~= ":" then
      error("colon expected")
    end
    i = skip(str, i + 1)
    local val
    val, i = parse_value(str, i)
    obj[key] = val
    i = skip(str, i)
    local c = str:sub(i, i)
    if c == "}" then
      return obj, i + 1
    elseif c == "," then
      i = skip(str, i + 1)
    else
      error("bad object at " .. i)
    end
  end
end

parse_value = function(str, i)
  i = skip(str, i)
  local c = str:sub(i, i)
  if c == '"' then
    return parse_string(str, i)
  elseif c == "{" then
    return parse_object(str, i)
  elseif c == "[" then
    return parse_array(str, i)
  elseif c == "t" and str:sub(i, i + 3) == "true" then
    return true, i + 4
  elseif c == "f" and str:sub(i, i + 4) == "false" then
    return false, i + 5
  elseif c == "n" and str:sub(i, i + 3) == "null" then
    return nil, i + 4
  elseif c:match("[%d%-]") then
    return parse_number(str, i)
  end
  error("unexpected at " .. i .. ": " .. c)
end

function json.decode(str)
  local v, i = parse_value(str, 1)
  return v
end

return json
