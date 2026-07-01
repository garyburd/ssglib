-- Site tests

local pandoc = require "pandoc"
local site_mod = require "ssglib.site"
local paths = require "ssglib.paths"
local test = require "tests.test"

local assert_equals = test.assert_equals
local assert_true = test.assert_true
local assert_false = test.assert_false

local minify = site_mod._test.minify_css
local prepare_js = site_mod._test.prepare_js

local function read_file(path)
  return pandoc.system.read_file(path)
end

local function file_exists(path)
  local success, _ = pcall(pandoc.system.read_file, path)
  return success
end

local capture_stderr = test.capture_stderr

local function assert_error_contains(fn, text)
  local success, err = pcall(fn)
  assert_false(success, "expected an error")
  assert_true(tostring(err):find(text, 1, true) ~= nil,
    string.format("expected error containing %q, got %q", text, tostring(err)))
end

local ok = true

pandoc.system.with_temporary_directory("site-test", function(tmpdir)
  ok = test.run_tests("", {
    "new",
    {
      "creates output directory",
      function()
        local dir = pandoc.path.join({ tmpdir, "new-site" })
        site_mod.Site.new(dir)
        assert_true(pandoc.path.exists(dir, "directory"))
      end,

      "default prefix",
      function()
        local dir = pandoc.path.join({ tmpdir, "default-prefix" })
        local s = site_mod.Site.new(dir)
        assert_equals(s.prefix, "/")
      end,

      "custom prefix",
      function()
        local dir = pandoc.path.join({ tmpdir, "custom-prefix" })
        local s = site_mod.Site.new(dir, "/blog/")
        assert_equals(s.prefix, "/blog/")
      end,

      "initial counters",
      function()
        local dir = pandoc.path.join({ tmpdir, "counters" })
        local s = site_mod.Site.new(dir)
        assert_equals(s.updated, 0)
        assert_equals(s.total, 0)
      end,
    },

    "prepare",
    {
      "maps url to path",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-map" })
        local s = site_mod.Site.new(dir)
        local path = s:prepare("/test.html")
        assert_equals(path, pandoc.path.join({ dir, "test.html" }))
      end,

      "trailing slash becomes index.html",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-index" })
        local s = site_mod.Site.new(dir)
        local path = s:prepare("/about/")
        assert_equals(path, pandoc.path.join({ dir, "about", "index.html" }))
      end,

      "creates subdirectories",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-subdir" })
        local s = site_mod.Site.new(dir)
        s:prepare("/deep/nested/file.html")
        assert_true(pandoc.path.exists(pandoc.path.join({ dir, "deep", "nested" }), "directory"))
      end,

      "increments total",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-total" })
        local s = site_mod.Site.new(dir)
        s:prepare("/a.html")
        s:prepare("/b.html")
        assert_equals(s.total, 2)
      end,

      "strips custom prefix",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-prefix" })
        local s = site_mod.Site.new(dir, "/blog/")
        local path = s:prepare("/blog/post.html")
        assert_equals(path, pandoc.path.join({ dir, "post.html" }))
      end,

      "tracks files",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-track" })
        local s = site_mod.Site.new(dir)
        local path = s:prepare("/test.html")
        assert_true(s.files[path])
      end,

      "rejects parent traversal",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-traversal" })
        local escaped = pandoc.path.join({ tmpdir, "escaped.txt" })
        local s = site_mod.Site.new(dir)
        assert_error_contains(function()
          s:write_data("/../escaped.txt", "outside")
        end, "must not contain . or ..")
        assert_false(file_exists(escaped))
      end,

      "rejects a colon segment that Windows joins as a drive",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-colon" })
        local s = site_mod.Site.new(dir)
        assert_error_contains(function()
          s:write_data("/C:evil.txt", "outside")
        end, "must not contain a colon")
      end,

      "raises on a duplicate write differing only in case",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-case" })
        local s = site_mod.Site.new(dir)
        s:write_data("/Same.html", "first")
        assert_error_contains(function()
          s:write_data("/same.html", "second")
        end, "duplicate write to /same.html (already claimed by /Same.html)")
      end,

      "raises on a duplicate write",
      function()
        local dir = pandoc.path.join({ tmpdir, "prep-duplicate" })
        local s = site_mod.Site.new(dir)
        s:write_data("/same.html", "first")
        assert_error_contains(function()
          s:write_data("/same.html", "second")
        end, "duplicate write to /same.html (already claimed by /same.html)")
      end,
    },

    "write_data",
    {
      "writes new file",
      function()
        local dir = pandoc.path.join({ tmpdir, "wd-new" })
        local s = site_mod.Site.new(dir)
        s:write_data("/test.html", "<h1>hello</h1>")
        assert_equals(read_file(pandoc.path.join({ dir, "test.html" })), "<h1>hello</h1>")
      end,

      "increments updated",
      function()
        local dir = pandoc.path.join({ tmpdir, "wd-updated" })
        local s = site_mod.Site.new(dir)
        s:write_data("/a.html", "a")
        assert_equals(s.updated, 1)
      end,

      "skips identical content",
      function()
        local dir = pandoc.path.join({ tmpdir, "wd-skip" })
        local s = site_mod.Site.new(dir)
        s:write_data("/test.html", "same")
        assert_equals(s.updated, 1)
        -- A fresh build skips unchanged data.
        local s2 = site_mod.Site.new(dir)
        s2:write_data("/test.html", "same")
        assert_equals(s2.updated, 0)
      end,

      "overwrites changed content",
      function()
        local dir = pandoc.path.join({ tmpdir, "wd-change" })
        local s = site_mod.Site.new(dir)
        s:write_data("/test.html", "old")
        -- A fresh build overwrites changed data.
        local s2 = site_mod.Site.new(dir)
        s2:write_data("/test.html", "new")
        assert_equals(read_file(pandoc.path.join({ dir, "test.html" })), "new")
        assert_equals(s2.updated, 1)
      end,

      "writes to subdirectory",
      function()
        local dir = pandoc.path.join({ tmpdir, "wd-sub" })
        local s = site_mod.Site.new(dir)
        s:write_data("/sub/page.html", "content")
        assert_equals(read_file(pandoc.path.join({ dir, "sub", "page.html" })), "content")
      end,
    },

    "write_file",
    {
      "copies file",
      function()
        local dir = pandoc.path.join({ tmpdir, "wf-copy" })
        local s = site_mod.Site.new(dir)
        local src = pandoc.path.join({ tmpdir, "source.txt" })
        pandoc.system.write_file(src, "file content")
        s:write_file("/copied.txt", src)
        assert_equals(read_file(pandoc.path.join({ dir, "copied.txt" })), "file content")
      end,

      "increments updated",
      function()
        local dir = pandoc.path.join({ tmpdir, "wf-updated" })
        local s = site_mod.Site.new(dir)
        local src = pandoc.path.join({ tmpdir, "source2.txt" })
        pandoc.system.write_file(src, "data")
        s:write_file("/file.txt", src)
        assert_equals(s.updated, 1)
      end,
    },

    "write_js",
    {
      "minifies each source independently",
      function()
        local dir = pandoc.path.join({ tmpdir, "wjs-mixed" })
        local s = site_mod.Site.new(dir)
        -- Only a lexer knows `/*` is inside a regex, so preserve that source;
        -- the second source is safe to minify.
        local hostile = "const path = /a\\/*b/; // keep\n"
        local plain = "  // header\n\n  a();\n"
        local expected = hostile .. "\na();"
        local url = s:write_js("/site.js", hostile, plain)
        assert_equals(read_file(pandoc.path.join({ dir, "site.js" })), expected)
        assert_equals(url, "/site.js?v=" .. pandoc.utils.sha1(expected))
      end,
    },

    "write_dir",
    {
      "copies directory contents",
      function()
        local dir = pandoc.path.join({ tmpdir, "wdir-test" })
        local s = site_mod.Site.new(dir)
        local srcdir = pandoc.path.join({ tmpdir, "srcdir" })
        pandoc.system.make_directory(srcdir, true)
        pandoc.system.write_file(pandoc.path.join({ srcdir, "a.txt" }), "aaa")
        pandoc.system.write_file(pandoc.path.join({ srcdir, "b.txt" }), "bbb")
        s:write_dir("/assets/", srcdir)
        assert_equals(read_file(pandoc.path.join({ dir, "assets", "a.txt" })), "aaa")
        assert_equals(read_file(pandoc.path.join({ dir, "assets", "b.txt" })), "bbb")
      end,

      "copies file symlinks but warns on directory symlinks",
      function()
        if pandoc.path.separator == "\\" then
          return
        end
        local dir = pandoc.path.join({ tmpdir, "wdir-symlink" })
        local srcdir = pandoc.path.join({ tmpdir, "wdir-symlink-src" })
        local external = pandoc.path.join({ tmpdir, "wdir-symlink-external" })
        pandoc.system.make_directory(srcdir, true)
        pandoc.system.make_directory(external, true)
        pandoc.system.write_file(pandoc.path.join({ external, "shared.txt" }), "shared")
        local rc = pandoc.system.command("ln",
          { "-s", pandoc.path.join({ external, "shared.txt" }), pandoc.path.join({ srcdir, "file-link.txt" }) })
        assert_false(rc, "could not create test symlink")
        rc = pandoc.system.command("ln", { "-s", external, pandoc.path.join({ srcdir, "dir-link" }) })
        assert_false(rc, "could not create test symlink")
        local s = site_mod.Site.new(dir)
        local warning = capture_stderr(function()
          s:write_dir("/assets/", srcdir)
        end)
        assert_equals(read_file(pandoc.path.join({ dir, "assets", "file-link.txt" })), "shared")
        assert_false(file_exists(pandoc.path.join({ dir, "assets", "dir-link", "shared.txt" })))
        assert_true(warning:find("not following directory symlink", 1, true) ~= nil, warning)
      end,
    },

    "cached",
    {
      "computes on miss and persists across instances",
      function()
        local dir = pandoc.path.join({ tmpdir, "cache-persist" })
        local src = pandoc.path.join({ tmpdir, "cache-src.txt" })
        pandoc.system.write_file(src, "hello")

        local s = site_mod.Site.new(dir)
        local calls = 0
        local v = s:cached(src, paths.stat(src), function()
          calls = calls + 1
          return { n = 42 }
        end)
        assert_equals(v.n, 42)
        assert_equals(calls, 1)
        s:cleanup()

        -- A fresh instance loads the manifest and hits unchanged sources.
        local s2 = site_mod.Site.new(dir)
        local calls2 = 0
        local v2 = s2:cached(src, paths.stat(src), function()
          calls2 = calls2 + 1
          return { n = 99 }
        end)
        assert_equals(v2.n, 42)
        assert_equals(calls2, 0)
      end,

      "recomputes when the stat changes",
      function()
        local dir = pandoc.path.join({ tmpdir, "cache-invalidate" })
        local src = pandoc.path.join({ tmpdir, "cache-src2.txt" })
        pandoc.system.write_file(src, "v1")
        local s = site_mod.Site.new(dir)
        assert_equals(s:cached(src, paths.stat(src), function() return "a" end), "a")
        -- Same stat: hit without computing.
        assert_equals(s:cached(src, paths.stat(src), function() return "b" end), "a")
        -- A different size triggers recomputation.
        pandoc.system.write_file(src, "v2-longer")
        assert_equals(s:cached(src, paths.stat(src), function() return "c" end), "c")
      end,

      "cleanup preserves the cache manifest",
      function()
        local dir = pandoc.path.join({ tmpdir, "cache-survives" })
        local s = site_mod.Site.new(dir)
        s:write_data("/keep.html", "keep")
        s:cleanup()
        assert_true(file_exists(pandoc.path.join({ dir, ".ssglib-cache.json" })))
      end,
    },

    "minify_css",
    {
      "removes comments and collapses whitespace",
      function()
        assert_equals(minify("/* hi */\na {\n  color: red;\n}\n"), "a{color:red}")
      end,

      "drops the final semicolon in a block",
      function()
        assert_equals(minify("a { color: red; }"), "a{color:red}")
      end,

      "trims spaces around selector commas and the child combinator",
      function()
        assert_equals(minify("h1, h2 > b { x: 1; }"), "h1,h2>b{x:1}")
      end,

      "preserves spaces between shorthand values",
      function()
        assert_equals(minify("p { margin: 1px 2px 3px; }"), "p{margin:1px 2px 3px}")
      end,

      "preserves required calc() operator spaces",
      function()
        assert_equals(minify("x { width: calc(10px + 2em); }"), "x{width:calc(10px + 2em)}")
      end,

      "trims spaces after value-list commas",
      function()
        assert_equals(minify("x { font: a, b, c; }"), "x{font:a,b,c}")
      end,

      "preserves whitespace inside string literals",
      function()
        assert_equals(minify('a::after { content: "x  y"; }'), 'a::after{content:"x  y"}')
      end,

      "keeps a comment sequence that lives inside a comment, not a string",
      function()
        -- Quotes inside comments must not corrupt output.
        assert_equals(minify("/* Gary's, Don't */ a { x: 1; }"), "a{x:1}")
      end,

      "preserves double quotes nested in a single-quoted string",
      function()
        assert_equals(minify([[a::after { content: 'say "hi"'; }]]), [[a::after{content:'say "hi"'}]])
      end,

      "preserves a comment sequence inside a string literal",
      function()
        assert_equals(minify('a::after { content: "/* not a comment */"; }'), 'a::after{content:"/* not a comment */"}')
      end,
    },

    "prepare_js",
    {
      "drops full-line comments, blank lines, and indentation",
      function()
        assert_equals(prepare_js("  // header\n\nvar x = 1;\n  run(); // tail\n"), "var x = 1;\nrun(); // tail")
      end,

      "keeps newlines between statements for ASI",
      function()
        assert_equals(prepare_js("function f() {\n  return\n  // note\n  42\n}\n"), "function f() {\nreturn\n42\n}")
      end,

      "does not touch whitespace or // inside a line",
      function()
        assert_equals(prepare_js("f('a  b', \"http://x/\");\n"), "f('a  b', \"http://x/\");")
      end,

      "handles CRLF line endings",
      function()
        assert_equals(prepare_js("a();\r\n// c\r\nb();\r\n"), "a();\nb();")
      end,

      "passes through sources with template literals",
      function()
        local js = "const s = `\n// not a comment\n`;\n"
        assert_equals(prepare_js(js), js)
      end,

      "passes through sources with block comments",
      function()
        local js = "let found = key/* separator */in object;\n"
        assert_equals(prepare_js(js), js)
      end,

      "passes through sources with a backslash line continuation",
      function()
        local js = 'var s = "a \\\n// still the string";\n'
        assert_equals(prepare_js(js), js)
      end,
    },

    "cleanup",
    {
      "removes unused files",
      function()
        local dir = pandoc.path.join({ tmpdir, "clean-unused" })
        local s = site_mod.Site.new(dir)
        pandoc.system.write_file(pandoc.path.join({ dir, "stale.html" }), "old")
        s:write_data("/keep.html", "keep")
        s:cleanup()
        assert_false(file_exists(pandoc.path.join({ dir, "stale.html" })))
        assert_true(file_exists(pandoc.path.join({ dir, "keep.html" })))
      end,

      "removes empty directories",
      function()
        local dir = pandoc.path.join({ tmpdir, "clean-dirs" })
        local s = site_mod.Site.new(dir)
        local subdir = pandoc.path.join({ dir, "empty-sub" })
        pandoc.system.make_directory(subdir, true)
        pandoc.system.write_file(pandoc.path.join({ subdir, "gone.html" }), "data")
        s:write_data("/keep.html", "data")
        s:cleanup()
        assert_false(file_exists(pandoc.path.join({ subdir, "gone.html" })))
        assert_false(pandoc.path.exists(subdir, "directory"))
      end,

      "removes a stale symlink without touching its target",
      function()
        if pandoc.path.separator == "\\" then
          return
        end
        local dir = pandoc.path.join({ tmpdir, "clean-symlink" })
        local external = pandoc.path.join({ tmpdir, "clean-symlink-external" })
        pandoc.system.make_directory(external, true)
        local keep = pandoc.path.join({ external, "keep.txt" })
        pandoc.system.write_file(keep, "keep")
        local s = site_mod.Site.new(dir)
        local link = pandoc.path.join({ dir, "link" })
        local rc = pandoc.system.command("ln", { "-s", external, link })
        assert_false(rc, "could not create test symlink")
        s:cleanup()
        assert_true(file_exists(keep), "cleanup followed the symlink")
        assert_false(paths.is_symlink(link), "cleanup did not remove the symlink")
      end,
    },
  }) and ok
end)

if not ok then
  os.exit(1)
end
