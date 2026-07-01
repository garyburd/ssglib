-- Path tests

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
    -- POSIX systems already use "/".
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

  "mailto scheme",
  function()
    assert_false(paths.is_local_path("mailto:user@example.com"))
  end,

  "tel scheme",
  function()
    assert_false(paths.is_local_path("tel:+15551234"))
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
-- file_exists Tests
-- ============================================================================

local file_exists_tests = {
  "non-existent file returns false",
  function()
    assert_false(paths.file_exists("/no/such/file"))
  end,

  "existing file returns true",
  function()
    pandoc.system.with_temporary_directory("exists-test", function(tmpdir)
      local path = pandoc.path.join({ tmpdir, "test.txt" })
      pandoc.system.write_file(path, "hello")
      assert_true(paths.file_exists(path))
    end)
  end,
}

-- ============================================================================
-- stat Tests
-- ============================================================================

local stat_tests = {
  "stat reports size and mtime",
  function()
    pandoc.system.with_temporary_directory("stat-test", function(tmpdir)
      local path = pandoc.path.join({ tmpdir, "test.txt" })
      pandoc.system.write_file(path, "hello")
      local st = paths.stat(path)
      assert_equals(st.size, 5)
      assert_true(st.mtime ~= "", "mtime should be non-empty")
    end)
  end,

  "stat of missing file",
  function()
    local st = paths.stat("/no/such/file")
    assert_equals(st.size, -1)
    assert_equals(st.mtime, "")
  end,

  "stat of empty file has size 0",
  function()
    pandoc.system.with_temporary_directory("stat-test", function(tmpdir)
      local path = pandoc.path.join({ tmpdir, "empty.txt" })
      pandoc.system.write_file(path, "")
      assert_equals(paths.stat(path).size, 0)
    end)
  end,

  "stat changes after a size change",
  function()
    pandoc.system.with_temporary_directory("stat-test", function(tmpdir)
      local path = pandoc.path.join({ tmpdir, "test.txt" })
      pandoc.system.write_file(path, "hello")
      local before = paths.stat(path)
      pandoc.system.write_file(path, "hello world")
      local after = paths.stat(path)
      assert_true(before.size ~= after.size, "size should differ")
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

  "reports but does not follow directory symlinks",
  function()
    if pandoc.path.separator == "\\" then
      return
    end
    pandoc.system.with_temporary_directory("walk-test", function(tmpdir)
      local root = pandoc.path.join({ tmpdir, "root" })
      local external = pandoc.path.join({ tmpdir, "external" })
      pandoc.system.make_directory(root, true)
      pandoc.system.make_directory(external, true)
      pandoc.system.write_file(pandoc.path.join({ external, "outside.txt" }), "outside")
      local link = pandoc.path.join({ root, "link" })
      local rc = pandoc.system.command("ln", { "-s", external, link })
      assert_false(rc, "could not create test symlink")

      local leaves = {}
      paths.walk_tree(root, function(path, is_symlink)
        table.insert(leaves, { name = pandoc.path.filename(path), is_symlink = is_symlink })
      end)
      assert_equals(#leaves, 1)
      assert_equals(leaves[1].name, "link")
      assert_true(leaves[1].is_symlink)
    end)
  end,
}

-- ============================================================================
-- stem Tests
-- ============================================================================

local stem_tests = {
  "simple filename",
  function()
    assert_equals(paths.stem("simple.md"), "simple")
  end,

  "filename with hyphens",
  function()
    assert_equals(paths.stem("with-frontmatter.md"), "with-frontmatter")
  end,

  "nested file",
  function()
    assert_equals(paths.stem("subdir/nested.md"), "nested")
  end,

  "non-markdown file",
  function()
    assert_equals(paths.stem("test.jpg"), "test")
  end,

  "file with multiple dots",
  function()
    assert_equals(paths.stem("photo.2024.jpg"), "photo.2024")
  end,

  "no extension",
  function()
    assert_equals(paths.stem("README"), "README")
  end,

  "dotted directory, filename without extension",
  function()
    assert_equals(paths.stem("dir.v2/file"), "file")
  end,

  "dotted directory, filename with extension",
  function()
    assert_equals(paths.stem("dir.v2/file.txt"), "file")
  end,
}

-- ============================================================================
-- remove_empty_dirs Tests
-- ============================================================================

local remove_empty_dirs_tests = {
  "removes empty subdirectories",
  function()
    pandoc.system.with_temporary_directory("red-test", function(tmpdir)
      local sub = pandoc.path.join({ tmpdir, "a", "b" })
      pandoc.system.make_directory(sub, true)
      paths.remove_empty_dirs(tmpdir)
      assert_false(pandoc.path.exists(pandoc.path.join({ tmpdir, "a" }), "directory"))
    end)
  end,

  "keeps subdirectories with files",
  function()
    pandoc.system.with_temporary_directory("red-test", function(tmpdir)
      local sub = pandoc.path.join({ tmpdir, "full" })
      pandoc.system.make_directory(sub, true)
      pandoc.system.write_file(pandoc.path.join({ sub, "keep.txt" }), "x")
      paths.remove_empty_dirs(tmpdir)
      assert_true(pandoc.path.exists(sub, "directory"))
    end)
  end,

  "keeps the root even when empty",
  function()
    pandoc.system.with_temporary_directory("red-test", function(tmpdir)
      local root = pandoc.path.join({ tmpdir, "site" })
      pandoc.system.make_directory(root, true)
      paths.remove_empty_dirs(root)
      assert_true(pandoc.path.exists(root, "directory"))
    end)
  end,
}

-- ============================================================================
-- Run tests
-- ============================================================================

local all_tests = {
  "change_path_separator",
  change_separator_tests,

  "path_conversion",
  path_conversion_tests,

  "is_local_path",
  is_local_path_tests,

  "file_exists",
  file_exists_tests,

  "stat",
  stat_tests,

  "walk_tree",
  walk_tree_tests,

  "stem",
  stem_tests,

  "remove_empty_dirs",
  remove_empty_dirs_tests,
}

if not test.run_tests("", all_tests) then
  os.exit(1)
end
