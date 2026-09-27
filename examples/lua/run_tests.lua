-- Headless runner for specs/pong/tests against the Lua pong_sim port.
-- Usage: love examples/lua -- --test

local json = require("json")
local sim = require("pong_sim")

local M = {}

local function resolve_tests_dir()
  local candidates = {}
  if love and love.filesystem then
    local src = love.filesystem.getSource()
    candidates[#candidates + 1] = src .. "/../../specs/pong/tests"
  end
  candidates[#candidates + 1] = "specs/pong/tests"
  candidates[#candidates + 1] = "../../specs/pong/tests"
  for _, c in ipairs(candidates) do
    local f = io.open(c .. "/MENU_CONFIRM_STARTS.json", "r")
    if f then
      f:close()
      return c
    end
  end
  return nil
end

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then
    return nil, err
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function list_json_files(dir)
  local files = {}
  local pipe = io.popen('ls "' .. dir .. '"/*.json 2>/dev/null')
  if pipe then
    for line in pipe:lines() do
      local base = line:match("([^/]+)%.json$")
      if base then
        files[#files + 1] = base
      end
    end
    pipe:close()
  end
  table.sort(files)
  return files
end

local function deep_merge(base, overlay)
  for key, value in pairs(overlay) do
    if type(value) == "table" and type(base[key]) == "table" then
      local has_string_key = false
      for k in pairs(value) do
        if type(k) == "string" then
          has_string_key = true
          break
        end
      end
      if has_string_key or next(value) == nil then
        deep_merge(base[key], value)
      else
        base[key] = value
      end
    else
      base[key] = value
    end
  end
end

local function expand_steps(steps)
  local frames = {}
  for _, step in ipairs(steps or {}) do
    local repeat_n = step["repeat"] or 1
    local frame = {
      held = step.held or {},
      pressed = step.pressed or {},
    }
    for _ = 1, repeat_n do
      frames[#frames + 1] = frame
    end
  end
  return frames
end

local function same_held(got, want)
  if #got ~= #want then
    return false
  end
  local gset, wset = {}, {}
  for _, a in ipairs(got) do
    gset[a] = true
  end
  for _, a in ipairs(want) do
    wset[a] = true
  end
  for a in pairs(gset) do
    if not wset[a] then
      return false
    end
  end
  for a in pairs(wset) do
    if not gset[a] then
      return false
    end
  end
  return true
end

local function nearly(a, b, eps)
  return math.abs(a - b) <= eps
end

local function check_partial(actual, expect, path, pos_eps, vel_eps)
  for key, want in pairs(expect) do
    local p = path == "" and key or (path .. "." .. key)
    local got = actual[key]
    if type(want) == "table" and type(got) == "table" then
      local err = check_partial(got, want, p, pos_eps, vel_eps)
      if err then
        return err
      end
    elseif type(want) == "number" and type(got) == "number" then
      local eps = pos_eps
      if key == "vx" or key == "vy" then
        eps = vel_eps
      end
      if not nearly(got, want, eps) then
        return string.format("%s: expected %s, got %s", p, tostring(want), tostring(got))
      end
    else
      if got ~= want then
        -- JSON null → Lua nil; allow false/true/string equality
        if not (want == nil and got == nil) then
          return string.format("%s: expected %s, got %s", p, tostring(want), tostring(got))
        end
      end
    end
  end
  return nil
end

local function run_test_file(path)
  local text, err = read_file(path)
  if not text then
    return "read failed: " .. tostring(err)
  end
  local ok, test = pcall(json.decode, text)
  if not ok or type(test) ~= "table" then
    return "invalid JSON"
  end

  local state = sim.boot_state()
  if test.initial then
    deep_merge(state, test.initial)
  end

  if test.ai_seat and type(test.expect) == "table" and test.expect.ai_held then
    local held = sim.ai_held(state, test.ai_seat)
    if not same_held(held, test.expect.ai_held) then
      return string.format(
        "ai_held: expected %s, got %s",
        json.encode(test.expect.ai_held),
        json.encode(held)
      )
    end
  end

  local use_ai = test.ai_seat and #(test.steps or {}) > 0
  local events = {}
  for _, frame in ipairs(expand_steps(test.steps)) do
    local held = {}
    for _, a in ipairs(frame.held) do
      held[#held + 1] = a
    end
    if use_ai then
      local seen = {}
      for _, a in ipairs(held) do
        seen[a] = true
      end
      for _, a in ipairs(sim.ai_held(state, test.ai_seat)) do
        if not seen[a] then
          held[#held + 1] = a
        end
      end
    end
    local ev = sim.step(state, held, frame.pressed)
    for _, e in ipairs(ev) do
      events[#events + 1] = e
    end
  end

  local expect = test.expect or {}
  local pos_eps = expect.position_epsilon or 1e-4
  local vel_eps = expect.velocity_epsilon or 1e-4

  if expect.state then
    local bad = check_partial(state, expect.state, "", pos_eps, vel_eps)
    if bad then
      return bad
    end
  end

  if expect.events then
    if expect.events_ordered then
      if json.encode(events) ~= json.encode(expect.events) then
        return string.format(
          "events: expected %s, got %s",
          json.encode(expect.events),
          json.encode(events)
        )
      end
    else
      local have = {}
      for _, e in ipairs(events) do
        have[e] = true
      end
      for _, name in ipairs(expect.events) do
        if not have[name] then
          return string.format("missing event %s; got %s", name, json.encode(events))
        end
      end
    end
  end

  return nil
end

function M.run()
  local dir = resolve_tests_dir()
  if not dir then
    print("Could not find specs/pong/tests")
    return 1
  end

  local files = list_json_files(dir)
  local passed, failed = 0, 0
  for _, id in ipairs(files) do
    local err = run_test_file(dir .. "/" .. id .. ".json")
    if err then
      print(string.format("FAIL  %s  %s", id, err))
      failed = failed + 1
    else
      print(string.format("PASS  %s", id))
      passed = passed + 1
    end
  end
  print(string.format("\n%d/%d passed", passed, passed + failed))
  return failed > 0 and 1 or 0
end

return M
