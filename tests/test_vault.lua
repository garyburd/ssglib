-- Vault tests

local pandoc = require "pandoc"
local vault = require "ssglib.vault"
local test = require "tests.test"

local assert_equals = test.assert_equals
local assert_not_nil = test.assert_not_nil
local assert_nil = test.assert_nil
local assert_true = test.assert_true
local assert_false = test.assert_false

local function write(tmpdir, name, content)
  pandoc.system.write_file(pandoc.path.join({ tmpdir, name }), content)
end

local function mkdir(tmpdir, name)
  local dir = pandoc.path.join({ tmpdir, name })
  pandoc.system.make_directory(dir, true)
  return dir
end

local ok = true

pandoc.system.with_temporary_directory("vault-test", function(tmpdir)
  -- Vault files
  local main = mkdir(tmpdir, "main")
  write(main, "simple.md", "# Simple Note\n\nThis is a simple note.")
  write(main, "with-frontmatter.md", [[---
permalink: custom-url/
date: 2024-01-15
tags:
  - test
  - example
hide: true
---

# Note with Front Matter

Content here.]])
  write(main, "with-links.md", [=[# Note with Links

This links to [[simple]] and [[with-frontmatter]].

External link: [Google](https://google.com)

Internal image: ![[test.jpg]]]=])
  write(main, "wikilink-syntax.md", [=[# Wikilink Variations

[[simple]]
[[simple|Custom Title]]
![[test.jpg]]
![[test.jpg|Alt text]]]=])
  write(main, "attached-image.md", "Attached text![[test.jpg]] here.\n")
  local sub = mkdir(main, "subdir")
  write(sub, "nested.md", "# Nested Note\n\nIn a subdirectory.")
  write(main, "test.jpg", "fake image data")

  local v = vault.Vault.new(main)

  -- Vault with a custom prefix
  local base = mkdir(tmpdir, "base")
  write(base, "simple.md", "# Simple\n")
  write(base, "page.md", "---\npermalink: custom/\n---\n\n# Page\n")
  local vbase = vault.Vault.new(base, "/ssglib/")

  -- Comparison vault with the default prefix
  local base_default = mkdir(tmpdir, "base-default")
  write(base_default, "simple.md", "# Simple\n")
  local vdefault = vault.Vault.new(base_default)

  -- Permalink fixtures
  local pdir = mkdir(tmpdir, "permalink")
  write(pdir, "no-frontmatter.md", "# Just a heading\n\nNo frontmatter here.\n")
  write(pdir, "unquoted.md", "---\npermalink: articles/hello/\n---\n\n# Hello\n")
  write(pdir, "single-quoted.md", "---\npermalink: 'articles/world/'\n---\n\n# World\n")
  write(pdir, "double-quoted.md", '---\npermalink: "articles/foo/"\n---\n\n# Foo\n')
  write(pdir, "no-permalink.md", "---\ndate: 2024-01-15\ntags:\n  - test\n---\n\n# No permalink\n")
  write(pdir, "empty-permalink.md", "---\npermalink:\n---\n\n# Empty\n")
  write(pdir, "space-permalink.md", "---\npermalink:   \n---\n\n# Space\n")
  write(pdir, "empty-quoted-permalink.md", '---\npermalink: ""\n---\n\n# EmptyQuoted\n')
  write(pdir, "mismatched-quoted.md", "---\npermalink: \"articles/mis/'\n---\n\n# Mismatched\n")
  write(pdir, "leading-slash.md", "---\npermalink: /articles/abs/\n---\n\n# Absolute\n")
  write(pdir, "crlf.md", "---\r\npermalink: articles/crlf/\r\n---\r\n\r\n# CRLF\r\n")
  local vp = vault.Vault.new(pdir)

  ok = test.run_tests("", {
    "scan",
    {
      "indexes file symlinks but warns on directory symlinks",
      function()
        if pandoc.path.separator == "\\" then
          return
        end
        local root = mkdir(tmpdir, "symlink-vault")
        local external = mkdir(tmpdir, "symlink-external")
        write(external, "linked.md", "# Linked\n")
        local rc = pandoc.system.command("ln",
          { "-s", pandoc.path.join({ external, "linked.md" }), pandoc.path.join({ root, "linked.md" }) })
        assert_false(rc, "could not create test symlink")
        rc = pandoc.system.command("ln", { "-s", external, pandoc.path.join({ root, "dir-link" }) })
        assert_false(rc, "could not create test symlink")
        local vs
        local warning = test.capture_stderr(function()
          vs = vault.Vault.new(root)
        end)
        assert_true(vs._paths["linked.md"], "file symlink was not indexed")
        assert_true(vs.notes:includes("linked.md"), "file symlink note missing")
        assert_nil(vs._paths["dir-link"])
        assert_true(warning:find("not following directory symlink", 1, true) ~= nil, warning)
      end,
    },

    "system_path",
    {
      "vault system_path for note",
      function()
        assert_equals(v:system_path("simple.md"), pandoc.path.join({ v.dir, "simple.md" }))
      end,

      "vault system_path for nested path",
      function()
        assert_equals(v:system_path("subdir/nested.md"), pandoc.path.join({ v.dir, "subdir", "nested.md" }))
      end,

      "vault system_path for image",
      function()
        assert_equals(v:system_path("test.jpg"), pandoc.path.join({ v.dir, "test.jpg" }))
      end,
    },

    "url",
    {
      "default url from filename",
      function()
        assert_equals(v:url("simple.md"), "/simple/")
      end,

      "url from permalink",
      function()
        assert_equals(v:url("with-frontmatter.md"), "/custom-url/")
      end,

      "url with hyphens",
      function()
        assert_equals(v:url("with-links.md"), "/with-links/")
      end,

      "nested file url",
      function()
        assert_equals(v:url("subdir/nested.md"), "/subdir/nested/")
      end,

      "url with custom prefix",
      function()
        assert_equals(vbase:url("simple.md"), "/ssglib/simple/")
      end,

      "url with custom prefix and permalink",
      function()
        assert_equals(vbase:url("page.md"), "/ssglib/custom/")
      end,

      "url with default prefix unchanged",
      function()
        assert_equals(vdefault:url("simple.md"), "/simple/")
      end,
    },

    "permalink",
    {
      "permalink is set",
      function()
        assert_equals(v._permalinks["with-frontmatter.md"], "custom-url/")
      end,

      "no permalink returns nil",
      function()
        assert_nil(v._permalinks["simple.md"])
      end,

      "no frontmatter returns nil permalink",
      function()
        assert_nil(vp._permalinks["no-frontmatter.md"])
      end,

      "unquoted permalink",
      function()
        assert_equals(vp._permalinks["unquoted.md"], "articles/hello/")
      end,

      "single-quoted permalink",
      function()
        assert_equals(vp._permalinks["single-quoted.md"], "articles/world/")
      end,

      "double-quoted permalink",
      function()
        assert_equals(vp._permalinks["double-quoted.md"], "articles/foo/")
      end,

      "no permalink field returns nil",
      function()
        assert_nil(vp._permalinks["no-permalink.md"])
      end,

      "empty permalink returns empty string",
      function()
        assert_equals("", vp._permalinks["empty-permalink.md"])
      end,

      "whitespace-only permalink returns empty string",
      function()
        assert_equals("", vp._permalinks["space-permalink.md"])
      end,

      "empty quoted permalink returns empty string",
      function()
        assert_equals("", vp._permalinks["empty-quoted-permalink.md"])
      end,

      "mismatched quotes kept verbatim",
      function()
        assert_equals("\"articles/mis/'", vp._permalinks["mismatched-quoted.md"])
      end,

      "permalink in a CRLF file",
      function()
        assert_equals(vp._permalinks["crlf.md"], "articles/crlf/")
      end,

      "leading-slash permalink rejected by url",
      function()
        local ok2 = pcall(function()
          return vp:url("leading-slash.md")
        end)
        assert_true(not ok2, "url with leading-slash permalink should error")
      end,
    },

    "vault_properties",
    {
      "vault root is set",
      function()
        assert_not_nil(v.dir)
      end,
    },

    "notes",
    {
      "notes has all entries",
      function()
        assert_equals(#v.notes, 6)
      end,
    },

    "document_parsing",
    {
      "parse document",
      function()
        local doc = v:doc("simple.md")
        assert_not_nil(doc)
        assert_not_nil(doc.meta)
      end,

      "wikilink image conversion",
      function()
        local doc = v:doc("wikilink-syntax.md")
        local has_image = false
        doc:walk({
          Image = function()
            has_image = true
            return nil
          end,
        })
        assert_true(has_image, "should convert ![[image]] to Image")
      end,

      "image embed attached to preceding text",
      function()
        local doc = v:doc("attached-image.md")
        local images = 0
        doc:walk({
          Image = function()
            images = images + 1
            return nil
          end,
        })
        assert_equals(images, 1)
        -- The Image consumes "!" but preserves attached text.
        assert_equals(pandoc.utils.stringify(doc.blocks[1]), "Attached text here.")
      end,
    },

    "resolve",
    {
      "resolve returns path for known link",
      function()
        local path = v:resolve("simple", "with-links.md")
        assert_equals(path, "simple.md")
      end,

      "resolve returns path for image link",
      function()
        local path = v:resolve("test.jpg", "with-links.md")
        assert_equals(path, "test.jpg")
      end,

      "resolve uses source context",
      function()
        local path = v:resolve("simple", "wikilink-syntax.md")
        assert_equals(path, "simple.md")
      end,

      "resolve returns nil for unknown link",
      function()
        local path = v:resolve("nonexistent", "simple.md")
        assert_nil(path)
      end,
    },

    "format_date",
    {
      "full month and year",
      function()
        assert_equals(vault.format_date("%B %Y", "2024-01-15"), "January 2024")
      end,

      "prefix text",
      function()
        assert_equals(vault.format_date(" / %B %Y", "2024-01-15"), " / January 2024")
      end,
    },
  }) and ok
end)

if not ok then
  os.exit(1)
end
