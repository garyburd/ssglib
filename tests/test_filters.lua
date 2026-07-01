-- Filter tests

local pandoc = require "pandoc"
local vault_mod = require "ssglib.vault"
local site_mod = require "ssglib.site"
local filters = require "ssglib.filters"
local test = require "tests.test"

local assert_equals = test.assert_equals
local assert_not_nil = test.assert_not_nil
local assert_nil = test.assert_nil
local assert_true = test.assert_true

local stringify = pandoc.utils.stringify

-- ============================================================================
-- Synthetic AVIF construction for dimension parsing
-- ============================================================================

--- Encode a 4-byte big-endian integer.
local function u32(n)
  return string.char(
    math.floor(n / 16777216) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256,
    n % 256)
end

--- Wrap a body in a BMFF box: length, type, body.
local function bmff_box(box_type, body)
  return u32(8 + #body) .. box_type .. body
end

--- An `ispe` FullBox: version/flags, width, height.
local function ispe(w, h)
  return bmff_box("ispe", u32(0) .. u32(w) .. u32(h))
end

--- Minimal AVIF: `ftyp`, then `meta > iprp > ipco` with the given properties.
local function avif_bytes(brands, ...)
  local props = table.concat({ ... })
  return bmff_box("ftyp", brands)
    .. bmff_box("meta", u32(0) .. bmff_box("iprp", bmff_box("ipco", props)))
end

-- ============================================================================
-- figure_filter Tests
-- ============================================================================

local figure_tests = {
  "non-image paragraph unchanged",
  function()
    local para = pandoc.Para({ pandoc.Str("just"), pandoc.Space(), pandoc.Str("text") })
    assert_nil(filters.figure_filter(para))
  end,

  "text before image unchanged",
  function()
    local para = pandoc.Para({ pandoc.Str("text"), pandoc.Space(), pandoc.Image("", "img.png") })
    assert_nil(filters.figure_filter(para))
  end,

  "lone image becomes captionless single-mode gallery Figure",
  function()
    local para = pandoc.Para({ pandoc.Image("", "image.png") })
    local result = filters.figure_filter(para)
    assert_not_nil(result)
    assert_equals(result.tag, "Figure")
    assert_true(result.classes:includes("gallery"), "gallery class present")
    assert_true(result.classes:includes("single"), "single mode class present")
    -- No trailing text means no caption.
    assert_equals(stringify(result.caption), "")
    local link = result.content[1].content[1]
    assert_equals(link.tag, "Link")
    assert_true(link.classes:includes("lightbox-link"), "lightbox-link class present")
  end,

  "image-led paragraph uses trailing text as caption and image title",
  function()
    local para = pandoc.Para({
      pandoc.Image("", "img.png"),
      pandoc.Space(),
      pandoc.Str("Caption"), pandoc.Space(), pandoc.Str("text"),
    })
    local result = filters.figure_filter(para)
    assert_equals(result.tag, "Figure")
    assert_equals(stringify(result.caption), "Caption text")
    -- The caption is also the lightbox title.
    local image = result.content[1].content[1].content[1]
    assert_equals(image.title, "Caption text")
  end,
}

-- ============================================================================
-- gallery_filter Tests
-- ============================================================================

-- Wrap blocks in a Div with the given classes.
local function div(classes, blocks)
  return pandoc.Div(blocks, pandoc.Attr("", classes))
end

local gallery_tests = {
  "div without a mode class is unchanged",
  function()
    local d = div({ "note" }, { pandoc.Para({ pandoc.Image("", "a.jpg") }) })
    assert_nil(filters.gallery_filter(d))
  end,

  "gallery becomes a Figure of lightbox tiles",
  function()
    local d = div({ "collage-portrait" }, { pandoc.Para({ pandoc.Image("", "a.jpg") }) })
    local result = filters.gallery_filter(d)
    assert_not_nil(result)
    assert_equals(result.tag, "Figure")
    assert_true(result.classes:includes("gallery"), "base gallery class added")
    assert_true(result.classes:includes("collage-portrait"), "mode class kept")
    local block = result.content[1]
    assert_equals(block.tag, "Plain")
    local link = block.content[1]
    assert_equals(link.tag, "Link")
    assert_true(link.classes:includes("lightbox-link"), "lightbox-link class present")
    assert_equals(link.content[1].tag, "Image")
  end,

  "trailing text becomes the image title, not a caption block",
  function()
    local d = div({ "collage-landscape" }, {
      pandoc.Para({ pandoc.Image("", "a.jpg"), pandoc.Space(), pandoc.Str("Sunset") }),
    })
    local result = filters.gallery_filter(d)
    -- Only the image tile; no caption.
    assert_equals(#result.content, 1)
    assert_equals(stringify(result.caption), "")
    local image = result.content[1].content[1].content[1]
    assert_equals(image.title, "Sunset")
  end,

  "aspect ratio is emitted from width and height",
  function()
    local img = pandoc.Image("", "a.jpg", "", pandoc.Attr("", {}, { width = "400", height = "200" }))
    local d = div({ "collage-landscape" }, { pandoc.Para({ img }) })
    local result = filters.gallery_filter(d)
    local link = result.content[1].content[1]
    assert_true(link.attributes.style:find("--aspect-ratio: 2.0000", 1, true) ~= nil,
      "style should carry the 2:1 aspect ratio")
  end,

  "non-image blocks are gathered into the figure caption",
  function()
    local d = div({ "collage-portrait" }, {
      pandoc.Para({ pandoc.Str("intro") }),
      pandoc.Para({ pandoc.Image("", "a.jpg") }),
      pandoc.Para({ pandoc.Str("outro") }),
    })
    local result = filters.gallery_filter(d)
    -- The tile remains as content; text forms the caption.
    assert_equals(#result.content, 1)
    assert_equals(result.content[1].tag, "Plain")
    assert_equals(#result.caption.long, 2)
    assert_equals(stringify(result.caption.long[1]), "intro")
    assert_equals(stringify(result.caption.long[2]), "outro")
  end,
}

-- ============================================================================
-- make_codeblock_filter Tests
-- ============================================================================

local codeblock_tests = {
  "non-eval block unchanged",
  function()
    local code = pandoc.CodeBlock("local x = 1", pandoc.Attr("", { "lua" }))
    local filter = filters.make_codeblock_filter()
    assert_nil(filter(code))
  end,

  "eval returns result",
  function()
    local code = pandoc.CodeBlock('pandoc.Para({pandoc.Str("hello")})', pandoc.Attr("", { "eval" }))
    local filter = filters.make_codeblock_filter()
    local result = filter(code)
    assert_equals(result.tag, "Para")
  end,

  "syntax error returns CodeBlock",
  function()
    local code = pandoc.CodeBlock("if then end", pandoc.Attr("", { "eval" }))
    local filter = filters.make_codeblock_filter()
    local result = filter(code)
    assert_equals(result.tag, "CodeBlock")
  end,

  "runtime error returns CodeBlock",
  function()
    local code = pandoc.CodeBlock('error("boom")', pandoc.Attr("", { "eval" }))
    local filter = filters.make_codeblock_filter()
    local result = filter(code)
    assert_equals(result.tag, "CodeBlock")
    assert_true(result.text:find("boom"), "should contain error message")
  end,

  "custom environment",
  function()
    local env = { x = 42 }
    local code = pandoc.CodeBlock("x", pandoc.Attr("", { "eval" }))
    local filter = filters.make_codeblock_filter(env)
    local result = filter(code)
    assert_equals(result, 42)
  end,

  "arguments passed to function",
  function()
    local code = pandoc.CodeBlock("...", pandoc.Attr("", { "eval" }))
    local filter = filters.make_codeblock_filter(nil, "hello")
    local result = filter(code)
    assert_equals(result, "hello")
  end,
}

-- ============================================================================
-- variant_url Tests
-- ============================================================================

local variant_url = filters._test.variant_url

local variant_tests = {
  "stable and shaped like <dir><16 hex chars>.webp",
  function()
    local url = variant_url("/photos/", "photo.jpg", 800)
    assert_equals(url, variant_url("/photos/", "photo.jpg", 800))
    assert_true(url:match("^/photos/%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%.webp$") ~= nil,
      "should be a 16-hex-char stem under the image directory")
  end,

  "sources differing only by extension get distinct names",
  function()
    assert_true(
      variant_url("/", "photo.jpg", 800) ~= variant_url("/", "photo.png", 800),
      "extension should be part of the hash"
    )
  end,

  "widths get distinct names",
  function()
    assert_true(
      variant_url("/", "photo.jpg", 800) ~= variant_url("/", "photo.jpg", 720),
      "width should be part of the hash"
    )
  end,
}

-- ============================================================================
-- parse_avif_size Tests
-- ============================================================================

local parse_avif_size = filters._test.parse_avif_size

local avif_tests = {
  "parses dimensions from the ispe box",
  function()
    local data = avif_bytes("avif" .. u32(0) .. "mif1", ispe(300, 200))
    local w, h = parse_avif_size(data)
    assert_equals(w, 300)
    assert_equals(h, 200)
  end,

  "largest ispe wins over thumbnail properties",
  function()
    local data = avif_bytes("avif" .. u32(0) .. "mif1", ispe(120, 90), ispe(2000, 1500))
    local w, h = parse_avif_size(data)
    assert_equals(w, 2000)
    assert_equals(h, 1500)
  end,

  "accepts avif among compatible brands of a generic HEIF major",
  function()
    local data = avif_bytes("mif1" .. u32(0) .. "miafavif", ispe(640, 480))
    local w, h = parse_avif_size(data)
    assert_equals(w, 640)
    assert_equals(h, 480)
  end,

  "rejects non-AVIF data",
  function()
    assert_nil(parse_avif_size("\255\216 jpeg-like data padded out"))
    assert_nil(parse_avif_size(avif_bytes("qt  " .. u32(0) .. "isom", ispe(300, 200))))
    assert_nil(parse_avif_size(""))
  end,
}

-- ============================================================================
-- Vault-dependent filter tests
-- ============================================================================

local ok = true

ok = test.run_tests("", {
  "figure_filter",
  figure_tests,
  "gallery_filter",
  gallery_tests,
  "make_codeblock_filter",
  codeblock_tests,
  "variant_url",
  variant_tests,
  "parse_avif_size",
  avif_tests,
}) and ok

pandoc.system.with_temporary_directory("filter-test", function(tmpdir)
  local vdir = pandoc.path.join({ tmpdir, "vault" })
  pandoc.system.make_directory(vdir, true)
  pandoc.system.write_file(pandoc.path.join({ vdir, "target.md" }), "# Target\n\nContent.")
  pandoc.system.write_file(pandoc.path.join({ vdir, "other.md" }), "---\npermalink: custom/\n---\n\n# Other\n")
  pandoc.system.write_file(pandoc.path.join({ vdir, "image.jpg" }), "fake image data")
  -- A parseable AVIF small enough to avoid gm resize variants.
  pandoc.system.write_file(pandoc.path.join({ vdir, "photo.avif" }),
    avif_bytes("avif" .. u32(0) .. "mif1", ispe(400, 300)))
  pandoc.system.write_file(pandoc.path.join({ vdir, "data.base" }), "base data")

  local v = vault_mod.Vault.new(vdir)
  local sdir = pandoc.path.join({ tmpdir, "site" })
  local s = site_mod.Site.new(sdir)

  -- ============================================================================
  -- make_link_filter Tests
  -- ============================================================================

  local link_tests = {
    "resolves vault link",
    function()
      local link = pandoc.Link("text", "target", "", pandoc.Attr("", { "wikilink" }))
      local filter = filters.make_link_filter(v, "other.md")
      local result = filter(link)
      assert_not_nil(result)
      assert_equals(result.target, "/target/")
    end,

    "resolves link with permalink",
    function()
      local link = pandoc.Link("text", "other", "", pandoc.Attr("", { "wikilink" }))
      local filter = filters.make_link_filter(v, "target.md")
      local result = filter(link)
      assert_not_nil(result)
      assert_equals(result.target, "/custom/")
    end,

    "preserves fragment",
    function()
      local link = pandoc.Link("text", "target#section", "", pandoc.Attr("", { "wikilink" }))
      local filter = filters.make_link_filter(v, "other.md")
      local result = filter(link)
      assert_not_nil(result)
      assert_equals(result.target, "/target/#section")
    end,

    "removes wikilink class",
    function()
      local link = pandoc.Link("text", "target", "", pandoc.Attr("", { "wikilink" }))
      local filter = filters.make_link_filter(v, "other.md")
      local result = filter(link)
      assert_not_nil(result)
      assert_true(not result.classes:includes("wikilink"), "wikilink class should be removed")
    end,

    "unresolvable link unchanged",
    function()
      local link = pandoc.Link("text", "nonexistent")
      local filter = filters.make_link_filter(v, "target.md")
      assert_nil(filter(link))
    end,

    "external link unchanged",
    function()
      local link = pandoc.Link("Google", "https://google.com")
      local filter = filters.make_link_filter(v, "target.md")
      assert_nil(filter(link))
    end,
  }

  -- ============================================================================
  -- make_image_filter Tests
  -- ============================================================================

  local image_tests = {
    "unresolvable image unchanged",
    function()
      local img = pandoc.Image("alt", "nonexistent.png")
      local filter = filters.make_image_filter(v, s, "target.md")
      assert_nil(filter(img))
    end,

    "base image returns nil",
    function()
      local img = pandoc.Image("", "data.base")
      local filter = filters.make_image_filter(v, s, "target.md")
      assert_nil(filter(img))
    end,

    "resolved image updates src",
    function()
      local img = pandoc.Image("alt", "image.jpg")
      local filter = filters.make_image_filter(v, s, "target.md")
      local result = filter(img)
      assert_not_nil(result)
      assert_equals(result.src, "/image.jpg")
    end,

    "avif image gets dimensions and srcset",
    function()
      local img = pandoc.Image("alt", "photo.avif")
      local filter = filters.make_image_filter(v, s, "target.md")
      local result = filter(img)
      assert_not_nil(result)
      assert_equals(result.src, "/photo.avif")
      assert_equals(result.attributes.width, "400")
      assert_equals(result.attributes.height, "300")
      assert_equals(result.attributes.srcset, "/photo.avif 400w")
      assert_equals(result.attributes.loading, "lazy")
    end,
  }

  ok = test.run_tests("", {
    "make_link_filter",
    link_tests,
    "make_image_filter",
    image_tests,
  }) and ok
end)

if not ok then
  os.exit(1)
end
