-- Test suite for paths module

local pandoc = require "pandoc"
local paths = require "ssglib.paths"
local test = require "tests.test"

local assert_equals = test.assert_equals
local assert_true = test.assert_true
local assert_false = test.assert_false

-- ============================================================================
-- change_path_separator Tests
-- ============================================================================

local change_path_separator = paths._test.change_path_separator

local change_separator_tests = {
  "replace forward slash with backslash",
  function()
    local convert = change_path_separator("/", "\\")
    assert_equals(convert("a/b/c"), "a\\b\\c")
  end,

  "replace backslash with forward slash",
  function()
    local convert = change_path_separator("\\", "/")
    assert_equals(convert("a\\b\\c"), "a/b/c")
  end,

  "same separator returns identity",
  function()
    local convert = change_path_separator("/", "/")
    assert_equals(convert("a/b/c"), "a/b/c")
  end,

  "no separator in string",
  function()
    local convert = change_path_separator("/", "\\")
    assert_equals(convert("abc"), "abc")
  end,

  "empty string",
  function()
    local convert = change_path_separator("/", "\\")
    assert_equals(convert(""), "")
  end,
}

-- ============================================================================
-- posix_path / system_path Tests
-- ============================================================================

local path_conversion_tests = {
  "posix_path is identity on POSIX systems",
  function()
    -- On macOS/Linux, separator is already "/", so posix_path is identity
    if pandoc.path.separator == "/" then
      assert_equals(paths.posix_path("a/b/c"), "a/b/c")
    end
  end,

  "system_path is identity on POSIX systems",
  function()
    if pandoc.path.separator == "/" then
      assert_equals(paths.system_path("a/b/c"), "a/b/c")
    end
  end,

  "posix_path roundtrips with system_path",
  function()
    local original = "a/b/c"
    assert_equals(paths.posix_path(paths.system_path(original)), original)
  end,
}

-- ============================================================================
-- is_local_path Tests
-- ============================================================================

local is_local_path_tests = {
  "relative path",
  function()
    assert_true(paths.is_local_path("image.png"))
  end,

  "relative path with directory",
  function()
    assert_true(paths.is_local_path("images/photo.jpg"))
  end,

  "absolute path",
  function()
    assert_true(paths.is_local_path("/images/photo.jpg"))
  end,

  "https url",
  function()
    assert_false(paths.is_local_path("https://example.com/image.png"))
  end,

  "protocol-relative url",
  function()
    assert_false(paths.is_local_path("//example.com/image.png"))
  end,

  "empty string",
  function()
    assert_true(paths.is_local_path(""))
  end,

  "fragment only",
  function()
    assert_true(paths.is_local_path("#section"))
  end,

  "path with query string",
  function()
    assert_true(paths.is_local_path("page?q=1"))
  end,
}

-- ============================================================================
-- file_mtime Tests
-- ============================================================================

local file_mtime_tests = {
  "non-existent file returns empty string",
  function()
    assert_equals(paths.file_mtime("/no/such/file"), "")
  end,

  "existing file returns non-empty string",
  function()
    pandoc.system.with_temporary_directory("mtime-test", function(tmpdir)
      local path = pandoc.path.join({ tmpdir, "test.txt" })
      pandoc.system.write_file(path, "hello")
      local mtime = paths.file_mtime(path)
      assert_true(mtime ~= "", "mtime should be non-empty")
    end)
  end,
}

-- ============================================================================
-- walk_tree Tests
-- ============================================================================

local walk_tree_tests = {
  "visits all files",
  function()
    pandoc.system.with_temporary_directory("walk-test", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "a.txt" }), "a")
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "b.txt" }), "b")
      local files = {}
      paths.walk_tree(tmpdir, function(path)
        table.insert(files, pandoc.path.filename(path))
      end)
      table.sort(files)
      assert_equals(#files, 2)
      assert_equals(files[1], "a.txt")
      assert_equals(files[2], "b.txt")
    end)
  end,

  "recurses into subdirectories",
  function()
    pandoc.system.with_temporary_directory("walk-test", function(tmpdir)
      local sub = pandoc.path.join({ tmpdir, "sub" })
      pandoc.system.make_directory(sub, true)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "top.txt" }), "top")
      pandoc.system.write_file(pandoc.path.join({ sub, "nested.txt" }), "nested")
      local files = {}
      paths.walk_tree(tmpdir, function(path)
        table.insert(files, pandoc.path.filename(path))
      end)
      table.sort(files)
      assert_equals(#files, 2)
      assert_equals(files[1], "nested.txt")
      assert_equals(files[2], "top.txt")
    end)
  end,

  "skips dotfiles",
  function()
    pandoc.system.with_temporary_directory("walk-test", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "visible.txt" }), "v")
      pandoc.system.write_file(pandoc.path.join({ tmpdir, ".hidden" }), "h")
      local files = {}
      paths.walk_tree(tmpdir, function(path)
        table.insert(files, pandoc.path.filename(path))
      end)
      assert_equals(#files, 1)
      assert_equals(files[1], "visible.txt")
    end)
  end,

  "skips dot directories",
  function()
    pandoc.system.with_temporary_directory("walk-test", function(tmpdir)
      local dotdir = pandoc.path.join({ tmpdir, ".hidden" })
      pandoc.system.make_directory(dotdir, true)
      pandoc.system.write_file(pandoc.path.join({ dotdir, "secret.txt" }), "s")
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "visible.txt" }), "v")
      local files = {}
      paths.walk_tree(tmpdir, function(path)
        table.insert(files, pandoc.path.filename(path))
      end)
      assert_equals(#files, 1)
      assert_equals(files[1], "visible.txt")
    end)
  end,

  "empty directory",
  function()
    pandoc.system.with_temporary_directory("walk-test", function(tmpdir)
      local files = {}
      paths.walk_tree(tmpdir, function(path)
        table.insert(files, path)
      end)
      assert_equals(#files, 0)
    end)
  end,
}

-- ============================================================================
-- Run All Tests
-- ============================================================================

local all_tests = {
  "change_path_separator",
  change_separator_tests,

  "path_conversion",
  path_conversion_tests,

  "is_local_path",
  is_local_path_tests,

  "file_mtime",
  file_mtime_tests,

  "walk_tree",
  walk_tree_tests,
}

if not test.run_tests("paths", all_tests) then
  os.exit(1)
end
