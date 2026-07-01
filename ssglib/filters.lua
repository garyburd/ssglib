--- Pandoc filters for building a static site from an Obsidian vault.
--- Dependencies: Pandoc, GraphicsMagick (gm convert command).

local pandoc = require "pandoc"
local parent = (...):match("(.-%.).+$") or ""
local paths = require(parent .. "paths")

--- Pandoc filters for building a static site from an Obsidian vault.
---@class ssglib.filters
local M = {}

-- ============================================================================
-- Image
-- ============================================================================

--- Resize an image into several copies with one gm invocation.
--- Each `-write` emits the current image, so later resizes use the previous,
--- smaller output. Order variants from largest to smallest.
---@param source string Source file path
---@param variants {width: integer, target: string}[] Outputs in descending width
local function resize_images(source, variants)
  local args = { "convert", source, "-quality", "87" }
  for i, variant in ipairs(variants) do
    table.insert(args, "-resize")
    table.insert(args, string.format("%dx", variant.width))
    if i < #variants then
      table.insert(args, "-write")
    end
    table.insert(args, variant.target)
  end
  -- `pandoc.system.command` returns false on success, otherwise the exit code.
  local rc, _, stderr = pandoc.system.command("gm", args)
  if rc then
    error(string.format("gm convert exited with status %d: %s", rc, stderr))
  end
end

--- Name an image variant from its filename and target width.
--- A 64-bit SHA-1 prefix keeps names distinct across source extensions and
--- makes accidental collisions negligible.
---@param dir string URL directory ending in "/"
---@param filename string Image filename, including extension
---@param width integer Variant width in pixels
---@return string url Variant URL
local function variant_url(dir, filename, width)
  local hash = pandoc.utils.sha1(string.format("%s\0%d", filename, width))
  return string.format("%s%s.webp", dir, hash:sub(1, 16))
end

--- Write an image and responsive variants.
---@param site ssglib.Site Destination site
---@param url string Target URL
---@param path string Source path
---@param stat Stat Source stat, reused for the original
---@param width integer Source width
---@return string srcset Comma-separated srcset attribute value
local function write_responsive_image(site, url, path, stat, width)
  -- Rebuild variants when the source changes or a variant is missing.
  local updated = site:write_file(url, path, stat)
  local dir, filename = url:match("^(.*/)(.*)$")
  local srcset = { string.format("%s %dw", url, width) }
  local scale = 0.9
  -- Keep the largest entry's format; emit smaller variants as WebP. Generate
  -- stale variants in one gm call, from largest to smallest.
  local pending = {}
  while width > 500 do
    width = math.floor(width * scale)
    scale = 0.66666
    url = variant_url(dir, filename, width)
    table.insert(srcset, string.format("%s %dw", url, width))
    local target = site:prepare(url)
    if updated or not paths.file_exists(target) then
      site.updated = site.updated + 1
      table.insert(pending, { width = width, target = target })
    end
  end
  if #pending > 0 then
    local ok, err = pcall(resize_images, path, pending)
    if not ok then
      error(string.format("Error resizing %s: %s", path, err))
    end
  end
  return table.concat(srcset, ", ")
end

-- ============================================================================
-- Image Properties
-- ============================================================================

--- Parse JPEG dimensions from binary data.
---@param data string JPEG data
---@return number|nil Width
---@return number|nil Height
local function parse_jpeg_size(data)
  if not data or #data < 2 then
    return nil, nil
  end

  -- Check the JPEG signature (FF D8).
  if data:byte(1) ~= 0xFF or data:byte(2) ~= 0xD8 then
    return nil, nil
  end

  local pos = 3 -- after the signature

  -- Scan for Start of Frame (SOF) markers.
  while pos < #data do
    -- Find the next marker (FF XX).
    if data:byte(pos) ~= 0xFF then
      break
    end

    local marker = data:byte(pos + 1)
    if not marker then
      break
    end

    pos = pos + 2

    -- SOF markers exclude C4, C8, and CC:
    -- SOF markers: C0-C3, C5-C7, C9-CB, CD-CF
    local is_sof = (marker >= 0xC0 and marker <= 0xC3)
      or (marker >= 0xC5 and marker <= 0xC7)
      or (marker >= 0xC9 and marker <= 0xCB)
      or (marker >= 0xCD and marker <= 0xCF)

    if is_sof then
      -- SOF segment:
      -- 2 bytes: segment length
      -- 1 byte: precision
      -- 2 bytes: height
      -- 2 bytes: width
      if pos + 7 > #data then
        break
      end

      -- Skip the length and precision.
      pos = pos + 3

      -- Read big-endian height.
      local h1, h2 = data:byte(pos, pos + 1)
      local height = h1 * 256 + h2
      pos = pos + 2

      -- Read big-endian width.
      local w1, w2 = data:byte(pos, pos + 1)
      local width = w1 * 256 + w2

      return width, height
    end

    -- Read this non-SOF segment's big-endian length.
    if pos + 1 > #data then
      break
    end
    local len1, len2 = data:byte(pos, pos + 1)
    local segment_length = len1 * 256 + len2

    if segment_length < 2 then
      break
    end

    -- Skip to the next segment.
    pos = pos + segment_length
  end

  -- No SOF marker.
  return nil, nil
end

--- Read a 4-byte big-endian unsigned integer.
local function read_u32(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
end

--- Parse AVIF dimensions from binary data.
--- AVIF is an ISO BMFF box tree. Dimensions live in `ispe` boxes under
--- `meta > iprp > ipco`, one per color image, alpha plane, or thumbnail.
--- Return the largest instead of resolving `pitm`/`ipma`: the alpha plane
--- matches the color image, and thumbnails are smaller.
---@param data string AVIF data
---@return number|nil Width
---@return number|nil Height
local function parse_avif_size(data)
  -- The first box must be `ftyp` with an AV1 image brand. Encoders may use a
  -- generic HEIF major brand and list `avif` as compatible, so search all.
  if #data < 16 or data:sub(5, 8) ~= "ftyp" then
    return nil, nil
  end
  local ftyp_end = math.min(read_u32(data, 1), #data)
  local brands = data:sub(9, ftyp_end)
  if not (brands:find("avif", 1, true) or brands:find("avis", 1, true)) then
    return nil, nil
  end

  local width, height

  -- Walk boxes in [pos, stop), following containers toward `ispe`. `meta` is
  -- a FullBox with version/flags; `iprp` and `ipco` are plain containers.
  local function walk(pos, stop)
    while pos + 8 <= stop do
      local size = read_u32(data, pos)
      local box_type = data:sub(pos + 4, pos + 7)
      if size == 0 then
        size = stop - pos -- box fills its container
      elseif size < 8 then
        return -- malformed or a 64-bit "largesize" box
      end
      local body = pos + 8
      if box_type == "meta" then
        walk(body + 4, math.min(pos + size, stop))
      elseif box_type == "iprp" or box_type == "ipco" then
        walk(body, math.min(pos + size, stop))
      elseif box_type == "ispe" and body + 12 <= pos + size then
        -- FullBox: version/flags, width, height.
        local w = read_u32(data, body + 4)
        local h = read_u32(data, body + 8)
        if not width or w * h > width * height then
          width, height = w, h
        end
      end
      pos = pos + size
    end
  end

  walk(1, #data + 1)
  return width, height
end

--- Read a file's image dimensions.
--- Return `pandoc.image.size`'s table shape, or nil if unknown.
---@param path string Image path
---@return {width: number, height: number}|nil size
local function read_image_size(path)
  local data = pandoc.system.read_file(path)

  -- Try the faster pure-Lua parsers first; Pandoc also lacks AVIF support.
  local width, height = parse_jpeg_size(data)
  if not width then
    width, height = parse_avif_size(data)
  end
  if width and height then
    return { width = width, height = height }
  end

  local ok, size = pcall(pandoc.image.size, data)
  if ok then
    return size
  end

  return nil
end

-- ============================================================================
-- Helpers
-- ============================================================================

--- Inline tags treated as whitespace separators.
local SPACE_TAGS = { Space = true, SoftBreak = true, LineBreak = true }

--- Warn about an unresolved local link.
local function warn_unresolved(target, source)
  if target ~= "" and paths.is_local_path(target) then
    io.stderr:write(string.format("ssglib: unresolved link %q in %s\n", target, source))
  end
end

--- Split an image-led paragraph into its image and caption.
--- Skip whitespace between them.
---@param para pandoc.Para
---@return pandoc.Image|nil image Leading image, or nil if not image-led
---@return pandoc.Inlines caption Inlines after the image (empty if none)
local function image_and_caption(para)
  local content = para.content
  if not content[1] or content[1].tag ~= "Image" then
    return nil, pandoc.Inlines({})
  end
  local scan = 2
  while content[scan] and SPACE_TAGS[content[scan].tag] do
    scan = scan + 1
  end
  local caption = pandoc.Inlines({})
  for i = scan, #content do
    caption:insert(content[i])
  end
  return content[1], caption
end

--- Remove an element's `wikilink` class.
local function remove_wikilink_class(x)
  local classes = x.classes
  local _, i = classes:find("wikilink")
  if not i then
    return nil
  end
  classes:remove(i)
  x.classes = classes
  return x
end

-- ============================================================================
-- Filters
-- ============================================================================

--- Wrap an image in a full-size `lightbox-link` inside a Plain block.
--- Without JavaScript, the link opens the image; with it, `gallery.js` opens
--- the lightbox. The caption becomes the image title, and `--aspect-ratio`
--- lets CSS size the tile. The image filter provides dimensions; CSS defaults
--- the ratio to 1.
---@param image pandoc.Image
---@param caption pandoc.Inlines
---@return pandoc.Plain tile
local function lightbox_tile(image, caption)
  -- Attributes require strings, so flatten the caption.
  if #caption > 0 then
    image.title = pandoc.utils.stringify(caption)
  end
  local attrs = { class = "lightbox-link" }
  local w = tonumber(image.attributes.width)
  local h = tonumber(image.attributes.height)
  if w and h and h > 0 then
    attrs.style = string.format("--aspect-ratio: %.4f", w / h)
  end
  return pandoc.Plain({ pandoc.Link({ image }, image.src, "", attrs) })
end

--- Convert an image-led paragraph to a single-image gallery `Figure`.
---
--- An image-led paragraph:
---
--- ```text
--- ![](https://example.com/image.png) caption
--- ```
---
--- becomes a `gallery single` Figure containing a lightbox tile and the
--- paragraph's remaining text as its caption. An image alone has no
--- `<figcaption>`; other paragraphs remain unchanged. The `single` layout
--- prevents the tile from exceeding the gallery's width in height.
---@param para pandoc.Para
---@return pandoc.Figure|nil converted Figure, or nil if not image-led
function M.figure_filter(para)
  local image, caption = image_and_caption(para)
  if not image then
    return nil
  end
  local cap = #caption > 0 and pandoc.Caption({ pandoc.Plain(caption) }) or pandoc.Caption()
  return pandoc.Figure({ lightbox_tile(image, caption) }, cap, pandoc.Attr("", { "gallery", "single" }))
end

--- Fenced-div gallery classes, which also select the CSS layout.
local GALLERY_MODES = {
  ["collage-landscape"] = true,
  ["collage-portrait"] = true,
}

--- Convert a fenced-div image gallery to a `Figure`.
---
--- A fenced div with a gallery-mode class:
---
--- ```text
--- ::: collage-landscape
--- ![](https://example.com/one.jpg) caption
---
--- ![](https://example.com/two.jpg)
---
--- Text about the gallery.
--- :::
--- ```
---
--- becomes a `gallery` Figure that retains the div's classes. Each image-led
--- paragraph becomes a lightbox tile; other blocks form one `<figcaption>`
--- after the tiles. Use separate galleries for content between image rows.
---
--- For a top-down walk, return `figure, false` to prevent paragraph filters
--- from reprocessing gallery images.
---@param div pandoc.Div
---@return pandoc.Figure|nil figure Gallery, or nil
---@return boolean? halt False after conversion to stop descent
function M.gallery_filter(div)
  local is_gallery = false
  for _, class in ipairs(div.classes) do
    if GALLERY_MODES[class] then
      is_gallery = true
      break
    end
  end
  if not is_gallery then
    return nil
  end

  local tiles = pandoc.Blocks({})
  local caption_blocks = pandoc.Blocks({})
  for _, block in ipairs(div.content) do
    local image, caption
    if block.tag == "Para" then
      image, caption = image_and_caption(block)
    end
    if image then
      tiles:insert(lightbox_tile(image, caption))
    else
      caption_blocks:insert(block)
    end
  end

  local classes = div.classes
  if not classes:includes("gallery") then
    classes:insert(1, "gallery")
  end
  local cap = #caption_blocks > 0 and pandoc.Caption(caption_blocks) or pandoc.Caption()
  return pandoc.Figure(tiles, cap, pandoc.Attr(div.identifier, classes, div.attributes)), false
end

--- Create a filter that copies vault images to the site.
--- Leave `.base` query embeds unchanged.
---@param vault ssglib.Vault
---@param site ssglib.Site
---@param source string Source path for resolving links
---@return fun(img: pandoc.Image): pandoc.Image|nil filter Image filter
function M.make_image_filter(vault, site, source)
  return function(img)
    local resolved = vault:resolve(img.src, source)
    if not resolved then
      warn_unresolved(img.src, source)
      return nil
    end
    if resolved:sub(-#".base") == ".base" then
      return nil
    end
    local url = vault:url(resolved)
    local path = vault:system_path(resolved)
    img.src = url
    -- Share one source stat between the dimension cache and original copy.
    local stat = paths.stat(path)
    -- Cache dimensions against the vault-relative path and source stat. The
    -- stable key survives vault moves; cached nils avoid retrying unreadable images.
    local size = site:cached(resolved, stat, function()
      return read_image_size(path)
    end)
    if size then
      local attrs = img.attributes
      attrs.srcset = write_responsive_image(site, url, path, stat, size.width)
      -- JSON turns cached dimensions into floats; format them as integers.
      attrs.width = string.format("%d", math.floor(size.width))
      attrs.height = string.format("%d", math.floor(size.height))
      attrs.sizes = "auto"
      attrs.loading = "lazy"
    else
      site:write_file(url, path, stat)
    end
    return img
  end
end

--- Create a filter that resolves vault links.
---@param vault ssglib.Vault
---@param source string Source path for resolving links
---@return fun(link: pandoc.Link): pandoc.Link|nil filter Link filter
function M.make_link_filter(vault, source)
  return function(link)
    local target = link.target
    local fragment = ""
    local hash_pos = target:find("#")
    if hash_pos then
      -- TODO: Slugify heading fragments. `[[Note#My Heading]]` retains
      -- `#My Heading`, but `gfm_auto_identifiers` emits `my-heading`. Apply the
      -- same normalization here. Block references (`#^block-id`) lack rendered
      -- anchors and remain unsupported.
      fragment = target:sub(hash_pos)
      target = target:sub(1, hash_pos - 1)
    end
    local resolved = vault:resolve(target, source)
    if not resolved then
      warn_unresolved(target, source)
      return nil
    end
    link.target = vault:url(resolved) .. fragment
    remove_wikilink_class(link)
    return link
  end
end

--- Create a filter that executes Lua code blocks.
---@param env table? Execution environment; defaults to `_G`
---@param ... any Arguments passed to executed code
---@return fun(code: pandoc.CodeBlock): pandoc.CodeBlock|pandoc.Block|nil filter Code-block filter
function M.make_codeblock_filter(env, ...)
  local args = table.pack(...)
  env = env or _G
  return function(code)
    if not code.classes:includes("eval") then
      return nil
    end
    local func, err = load("return " .. code.text, "=(eval)", "t", env)
    if not func then
      return pandoc.CodeBlock(tostring(err))
    end
    local ok, result = pcall(func, table.unpack(args))
    if not ok then
      return pandoc.CodeBlock(tostring(result))
    end
    return result
  end
end

-- ============================================================================
-- Module Exports
-- ============================================================================

M._test = {
  parse_avif_size = parse_avif_size,
  variant_url = variant_url,
}

return M
