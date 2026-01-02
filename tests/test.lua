-- Test runner module for Lua test suites

-- ============================================================================
-- Test Configuration
-- ============================================================================

local VERBOSE = os.getenv("VERBOSE") == "1" or os.getenv("VERBOSE") == "true"

-- ============================================================================
-- Assertion Functions
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

-- ============================================================================
-- Test Runner
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
-- Module Exports
-- ============================================================================

return {
  assert_equals = assert_equals,
  assert_true = assert_true,
  assert_false = assert_false,
  assert_not_nil = assert_not_nil,
  assert_nil = assert_nil,
  run_tests = run_tests,
}
