-- Test suite for vault module

local pandoc = require "pandoc"
local vault = require "ssglib.vault"
local test = require "tests.test"

local assert_equals = test.assert_equals
local assert_not_nil = test.assert_not_nil
local assert_nil = test.assert_nil
local assert_true = test.assert_true
local assert_false = test.assert_false

-- ============================================================================
-- Test Vault Setup
-- ============================================================================

local function create_test_vault(tmpdir)
  -- Create test markdown files
  pandoc.system.write_file(pandoc.path.join({ tmpdir, "simple.md" }), "# Simple Note\n\nThis is a simple note.")

  pandoc.system.write_file(
    pandoc.path.join({ tmpdir, "with-frontmatter.md" }),
    [[---
permalink: /custom-url/
date: 2024-01-15
tags:
  - test
  - example
hide: true
---

# Note with Front Matter

Content here.]]
  )

  pandoc.system.write_file(
    pandoc.path.join({ tmpdir, "with-links.md" }),
    [=[# Note with Links

This links to [[simple]] and [[with-frontmatter]].

External link: [Google](https://google.com)

Internal image: ![[test.jpg]]]=]
  )

  pandoc.system.write_file(
    pandoc.path.join({ tmpdir, "wikilink-syntax.md" }),
    [=[# Wikilink Variations

[[simple]]
[[simple|Custom Title]]
![[test.jpg]]
![[test.jpg|Alt text]]]=]
  )

  -- Create a subdirectory with a note
  local subdir = pandoc.path.join({ tmpdir, "subdir" })
  pandoc.system.make_directory(subdir, true)
  pandoc.system.write_file(pandoc.path.join({ subdir, "nested.md" }), "# Nested Note\n\nIn a subdirectory.")

  -- Create a test image (minimal JPEG)
  -- FF D8 (SOI), FF C0 (SOF0), length, precision, height, width, FF D9 (EOI)
  local jpeg_data = string.char(
    0xFF,
    0xD8, -- SOI
    0xFF,
    0xC0, -- SOF0
    0x00,
    0x11, -- Length (17 bytes)
    0x08, -- Precision
    0x00,
    0x64, -- Height (100)
    0x00,
    0xC8, -- Width (200)
    0x03, -- Number of components
    0x01,
    0x22,
    0x00, -- Component 1
    0x02,
    0x11,
    0x01, -- Component 2
    0x03,
    0x11,
    0x01, -- Component 3
    0xFF,
    0xD9 -- EOI
  )
  pandoc.system.write_file(pandoc.path.join({ tmpdir, "test.jpg" }), jpeg_data)

  -- Create other file types
  pandoc.system.write_file(pandoc.path.join({ tmpdir, "image.png" }), "fake png data")

  pandoc.system.write_file(pandoc.path.join({ tmpdir, "data.txt" }), "some text file")

  return vault.Vault.load(tmpdir)
end

-- ============================================================================
-- Test Suites (constructed from a loaded vault)
-- ============================================================================

local function vault_tests(v)
  return {
    -- ========================================================================
    -- File Type Tests
    -- ========================================================================
    "file_type",
    {
      "markdown file is note type",
      function()
        local f = v:get("simple.md")
        assert_not_nil(f)
        assert_equals(f:type(), "note")
      end,

      "jpeg file is image type",
      function()
        local f = v:get("test.jpg")
        assert_not_nil(f)
        assert_equals(f:type(), "image")
      end,

      "txt file is other type",
      function()
        local f = v:get("data.txt")
        assert_not_nil(f)
        assert_equals(f:type(), "other")
      end,
    },

    -- ========================================================================
    -- File Lookup Tests
    -- ========================================================================
    "file_lookup",
    {
      "get file with extension",
      function()
        local f = v:get("simple.md")
        assert_not_nil(f)
        assert_equals(f.path, "simple.md")
      end,

      "get file without extension",
      function()
        local f = v:get("simple")
        assert_not_nil(f)
        assert_equals(f.path, "simple.md")
      end,

      "get nested file",
      function()
        local f = v:get("subdir/nested.md")
        assert_not_nil(f)
        assert_equals(f.path, "subdir/nested.md")
      end,

      "get non-existent file returns nil",
      function()
        local f = v:get("does-not-exist.md")
        assert_nil(f)
      end,

      "get image file",
      function()
        local f = v:get("test.jpg")
        assert_not_nil(f)
        assert_equals(f.path, "test.jpg")
      end,
    },

    -- ========================================================================
    -- File Title Tests
    -- ========================================================================
    "file_title",
    {
      "simple filename",
      function()
        local f = v:get("simple.md")
        assert_equals(f:title(), "simple")
      end,

      "filename with hyphens",
      function()
        local f = v:get("with-frontmatter.md")
        assert_equals(f:title(), "with-frontmatter")
      end,

      "nested file title",
      function()
        local f = v:get("subdir/nested.md")
        assert_equals(f:title(), "nested")
      end,

      "image file title",
      function()
        local f = v:get("test.jpg")
        assert_equals(f:title(), "test")
      end,
    },

    -- ========================================================================
    -- URL Generation Tests
    -- ========================================================================
    "url_generation",
    {
      "default url from filename",
      function()
        local f = v:get("simple.md")
        assert_equals(f:url(), "/simple/")
      end,

      "url from permalink",
      function()
        local f = v:get("with-frontmatter.md")
        assert_equals(f:url(), "/custom-url/")
      end,

      "url with hyphens",
      function()
        local f = v:get("with-links.md")
        assert_equals(f:url(), "/with-links/")
      end,

      "nested file url",
      function()
        local f = v:get("subdir/nested.md")
        assert_equals(f:url(), "/subdir/nested/")
      end,
    },

    -- ========================================================================
    -- Front Matter Tests
    -- ========================================================================
    "frontmatter",
    {
      "parse permalink",
      function()
        local f = v:get("with-frontmatter.md")
        assert_equals(f.properties.permalink, "custom-url/")
      end,

      "parse date",
      function()
        local f = v:get("with-frontmatter.md")
        assert_equals(f.properties.date, "2024-01-15")
      end,

      "parse hide flag",
      function()
        local f = v:get("with-frontmatter.md")
        assert_true(f.properties.hide)
      end,

      "parse tags",
      function()
        local f = v:get("with-frontmatter.md")
        assert_not_nil(f.properties.tags)
        assert_equals(#f.properties.tags, 2)
        assert_equals(f.properties.tags[1], "test")
        assert_equals(f.properties.tags[2], "example")
      end,

      "no front matter returns empty properties",
      function()
        local f = v:get("simple.md")
        assert_nil(f.properties.permalink)
        assert_nil(f.properties.date)
        assert_nil(f.properties.hide)
      end,
    },

    -- ========================================================================
    -- Link Extraction Tests
    -- ========================================================================
    "link_extraction",
    {
      "find wikilinks",
      function()
        local f = v:get("with-links.md")
        local links = f.properties.links
        assert_not_nil(links)
        local found_simple = false
        local found_frontmatter = false
        local found_image = false
        for _, link in ipairs(links) do
          if link == "simple" then
            found_simple = true
          end
          if link == "with-frontmatter" then
            found_frontmatter = true
          end
          if link == "test.jpg" then
            found_image = true
          end
        end
        assert_true(found_simple, "should find link to simple")
        assert_true(found_frontmatter, "should find link to with-frontmatter")
        assert_true(found_image, "should find image link")
      end,

      "no external links",
      function()
        local f = v:get("with-links.md")
        local links = f.properties.links
        for _, link in ipairs(links) do
          assert_false(link:match("^https?://"), "should not include external links")
        end
      end,

      "empty links for file without links",
      function()
        local f = v:get("simple.md")
        local links = f.properties.links
        assert_not_nil(links)
        assert_equals(#links, 0)
      end,
    },

    -- ========================================================================
    -- Image Properties Tests
    -- ========================================================================
    "image_properties",
    {
      "read jpeg dimensions",
      function()
        local f = v:get("test.jpg")
        assert_not_nil(f.properties.width)
        assert_not_nil(f.properties.height)
        assert_equals(f.properties.width, 200)
        assert_equals(f.properties.height, 100)
      end,
    },

    -- ========================================================================
    -- Vault Query Tests
    -- ========================================================================
    "vault_queries",
    {
      "notes returns only note files",
      function()
        local notes = v:notes()
        assert_not_nil(notes)
        assert_true(#notes > 0)
        for _, note in ipairs(notes) do
          assert_equals(note:type(), "note")
        end
      end,

      "notes includes all markdown files",
      function()
        local notes = v:notes()
        local count = 0
        for _, f in pairs(v.files) do
          if f:type() == "note" then
            count = count + 1
          end
        end
        assert_equals(#notes, count)
      end,
    },

    -- ========================================================================
    -- Document Parsing Tests
    -- ========================================================================
    "document_parsing",
    {
      "parse document",
      function()
        local f = v:get("simple.md")
        local doc = f:doc()
        assert_not_nil(doc)
        assert_not_nil(doc.meta)
      end,

      "wikilink image conversion",
      function()
        local f = v:get("wikilink-syntax.md")
        local doc = f:doc()
        local has_image = false
        doc:walk({
          Image = function()
            has_image = true
            return nil
          end,
        })
        assert_true(has_image, "should convert ![[image]] to Image")
      end,
    },
  }
end

-- ============================================================================
-- format_date Tests
-- ============================================================================

local format_date_tests = {
  "full month and year",
  function()
    assert_equals(vault.format_date("%B %Y", "2024-01-15"), "January 2024")
  end,

  "prefix text",
  function()
    assert_equals(vault.format_date(" / %B %Y", "2024-01-15"), " / January 2024")
  end,
}

-- ============================================================================
-- Cache Tests
-- ============================================================================

local cache_tests = {
  "vault loads with cache",
  function()
    pandoc.system.with_temporary_directory("cache-test", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "note.md" }), "# Test")

      local cache_path = pandoc.path.join({ tmpdir, "cache.json" })

      -- Load vault (creates cache)
      local v1 = vault.Vault.load(tmpdir, cache_path)
      assert_not_nil(v1:get("note.md"))

      -- Load again (uses cache)
      local v2 = vault.Vault.load(tmpdir, cache_path)
      assert_not_nil(v2:get("note.md"))
      assert_equals(v2:get("note.md").path, "note.md")
    end)
  end,

  "vault without cache",
  function()
    pandoc.system.with_temporary_directory("no-cache-test", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "note.md" }), "# Test")

      local v = vault.Vault.load(tmpdir, nil)
      assert_not_nil(v:get("note.md"))
    end)
  end,
}

-- ============================================================================
-- Base URL Tests
-- ============================================================================

local base_url_tests = {
  "url with custom base",
  function()
    pandoc.system.with_temporary_directory("base-url-test", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "simple.md" }), "# Simple")
      local v = vault.Vault.load(tmpdir, nil, "/ssglib/")
      local f = v:get("simple.md")
      assert_not_nil(f)
      assert_equals(f:url(), "/ssglib/simple/")
    end)
  end,

  "url with custom base and permalink",
  function()
    pandoc.system.with_temporary_directory("base-url-test2", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "page.md" }), "---\npermalink: /custom/\n---\n# Page")
      local v = vault.Vault.load(tmpdir, nil, "/ssglib/")
      local f = v:get("page.md")
      assert_not_nil(f)
      assert_equals(f:url(), "/ssglib/custom/")
    end)
  end,

  "url with default base unchanged",
  function()
    pandoc.system.with_temporary_directory("base-url-test3", function(tmpdir)
      pandoc.system.write_file(pandoc.path.join({ tmpdir, "simple.md" }), "# Simple")
      local v = vault.Vault.load(tmpdir, nil)
      local f = v:get("simple.md")
      assert_not_nil(f)
      assert_equals(f:url(), "/simple/")
    end)
  end,
}

-- ============================================================================
-- Run All Tests
-- ============================================================================

local ok = true

-- Run main vault tests inside the temporary directory so files remain
-- accessible for File:doc() calls.
pandoc.system.with_temporary_directory("vault-test", function(tmpdir)
  local v = create_test_vault(tmpdir)
  ok = test.run_tests("vault", vault_tests(v)) and ok
end)

-- format_date and cache tests don't need the vault fixture.
ok = test.run_tests("vault", {
  "format_date", format_date_tests,
  "cache", cache_tests,
  "base_url", base_url_tests,
}) and ok

if not ok then
  os.exit(1)
end
