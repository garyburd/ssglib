-- Lua test runner

-- ============================================================================
-- Configuration
-- ============================================================================

local VERBOSE = os.getenv("VERBOSE") == "1" or os.getenv("VERBOSE") == "true"

-- ============================================================================
-- Assertions
-- ============================================================================

local function assert_equals(got, want, message)
  if got ~= want then
    error(string.format("%sgot: %s, want: %s", message and (message .. ": ") or "", tostring(got), tostring(want)), 0)
  end
end

local function assert_true(condition, message)
  if not condition then
    error(message or "assertion failed: expected true", 0)
  end
end

local function assert_false(condition, message)
  if condition then
    error(message or "assertion failed: expected false", 0)
  end
end

local function assert_not_nil(value, message)
  if value == nil then
    error(message or "assertion failed: expected non-nil value", 0)
  end
end

local function assert_nil(value, message)
  if value ~= nil then
    error(string.format("%sexpected nil, got: %s", message and (message .. ": ") or "", tostring(value)), 0)
  end
end

-- Capture `fn`'s stderr in memory, restoring the real stream if it raises.
local function capture_stderr(fn)
  local old_stderr = io.stderr
  local output = {}
  io.stderr = {
    write = function(_, value)
      table.insert(output, value)
    end,
  }
  local success, err = xpcall(fn, debug.traceback)
  io.stderr = old_stderr
  if not success then
    error(err, 0)
  end
  return table.concat(output)
end

-- ============================================================================
-- Runner
-- ============================================================================

local function run_tests(name, tests)
  local ok = true
  for i = 1, #tests, 2 do
    local n = string.format("%s/%s", name, tests[i])
    local t = tests[i + 1]
    if type(t) == "table" then
      ok = run_tests(n, t) and ok
    else
      if VERBOSE then
        io.write(string.format("%s ... ", n))
        io.flush()
      end
      local success, err = xpcall(t, debug.traceback)
      if not success then
        ok = false
        if VERBOSE then
          print("FAIL")
        end
        print(string.format("%s: %s", n, err))
      elseif VERBOSE then
        print("ok")
      end
    end
  end
  return ok
end

-- ============================================================================
-- Exports
-- ============================================================================

return {
  assert_equals = assert_equals,
  assert_true = assert_true,
  assert_false = assert_false,
  assert_not_nil = assert_not_nil,
  assert_nil = assert_nil,
  capture_stderr = capture_stderr,
  run_tests = run_tests,
}
