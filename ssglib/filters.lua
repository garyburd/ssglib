--- Pandoc filters for generating a static website from an Obsidian vault.
--- Dependencies: Pandoc, ImageMagick/GraphicsMagick convert command.

local pandoc = require "pandoc"
local parent = (...):match("(.-%.).+$") or ""
local paths = require(parent .. "paths")

-- ============================================================================
-- Image
-- ============================================================================

--- Resize image to specified width.
--- @param target string Output file path.
--- @param source string Source file path.
--- @param width integer Width
local function resize_image(target, source, width)
  pandoc.system.command("gm", { "convert", source, "-resize", string.format("%dx", width), "-quality", "87", target })
end

--- Write responsive image with multiple sizes.
--- @param site Site Destination site.
--- @param url string Target URL.
--- @param path string Source path.
--- @param mtime string Source file modification in ISO 8601 format.
--- @param width integer Source file image width.
--- @return string srcset Comma-separated srcset attribute value
local function write_responsive_image(site, url, path, mtime, width)
  mtime = mtime or paths.file_mtime(path)
  site:write_file(url, path, mtime)
  local name, ext = pandoc.path.split_extension(url)
  local srcset = { string.format("%s %dw", url, width) }
  while width > 500 do
    width = math.floor(width * 0.66666)
    url = string.format("%s-%x%s", name, width, ext)
    table.insert(srcset, string.format("%s %dw", url, width))
    local target = site:prepare(url)
    if paths.file_mtime(target) < mtime then
      site.updated = site.updated + 1
      local ok, err = pcall(resize_image, target, path, width)
      if not ok then
        error(string.format("Error resizing %s: %s", path, err))
      end
    end
  end
  return table.concat(srcset, ", ")
end

-- ============================================================================
-- Helpers
-- ============================================================================

--- Skip whitespace and line break inlines.
--- @param inlines pandoc.Inlines
--- @param i integer
--- @return integer next_index Next non-space index
local function skip_space(inlines, i)
  local inline = inlines[i]
  if inline then
    local tag = inline.tag
    if tag == "Space" or tag == "SoftBreak" or tag == "LineBreak" then
      i = i + 1
    end
  end
  return i
end

--- Remove the "wikilink" class from a Pandoc element's class list.
local function remove_wikilink_class(x)
  local _, i = x.classes:find("wikilink")
  if not i then
    return nil
  end
  x.classes:remove(i)
  return x
end

-- ============================================================================
-- Filters
-- ============================================================================

--- Pandoc Lua filter to convert BlockQuotes with
--- a callout markers to a Div or a Figure.
---
--- Converts:
---
--- > [!figure] ![alt](image.png)
--- > caption
---
--- to a Pandoc Figure element. Also converts:
---
--- > [!marker] content
---
--- to a Div with classes "callout-marker" and "callout".
--- @param blockquote pandoc.BlockQuote
--- @return pandoc.Figure|pandoc.Div|nil converted Converted element or nil if no conversion
local function callout_filter(blockquote)
  local block = blockquote.content[1]
  if not block or block.tag ~= "Para" then
    return nil
  end
  local inline = block.content[1]
  if not inline or inline.tag ~= "Str" then
    return nil
  end
  local marker = inline.text:match("^%[!(.+)%]$")
  if not marker then
    return nil
  end

  -- Start scan after marker and any following space.
  local scan = skip_space(block.content, 2)

  -- Handle [!figure] specially
  if marker == "figure" then
    local content = nil
    inline = block.content[scan]
    if inline and inline.tag == "Image" then
      content = pandoc.Plain({ inline })
      scan = skip_space(block.content, scan + 1)
    else
      content = pandoc.Plain()
    end
    -- Shift elements left to remove the leading marker and space. The end index
    -- intentionally extends past the array; the out-of-range nils overwrite the
    -- now-unused trailing slots, shrinking the sequence.
    table.move(block.content, scan, scan + #block.content, 1)
    return pandoc.Figure(content, pandoc.Caption({ pandoc.utils.blocks_to_inlines(blockquote.content) }))
  end

  -- Shift elements left to remove the leading marker and space. The end index
  -- intentionally extends past the array; the out-of-range nils overwrite the
  -- now-unused trailing slots, shrinking the sequence.
  table.move(block.content, scan, scan + #block.content, 1)
  return pandoc.Div(blockquote.content, pandoc.Attr("", { "callout", "callout-" .. marker }, {}))
end

--- Create an image filter for processing vault images.
--- The filter copies images from the vault to the site.
--- @param vault Vault
--- @param site Site
--- @return fun(img: pandoc.Image): pandoc.Image|nil filter Image filter function
local function make_image_filter(vault, site)
  return function(img)
    local file = vault:get(img.src)
    if not file then
      return nil
    end
    local url = file:url()
    img.src = url
    local attrs = img.attributes
    attrs.srcset = write_responsive_image(site, url, file.file_path, file.mtime, file.properties.width)
    attrs.width = file.properties.width
    attrs.height = file.properties.height
    if attrs.srcset then
      attrs.sizes = "auto"
      attrs.loading = "lazy"
    end
    if attrs.width and attrs.height then
      attrs.style = string.format("--aspect-ratio: %.3f", tonumber(attrs.width) / tonumber(attrs.height))
    end
    return img
  end
end

--- Create a link filter for resolving vault links.
--- @param vault Vault
--- @return fun(link: pandoc.Link): pandoc.Link|nil filter Link filter function
local function make_link_filter(vault)
  return function(link)
    local file = vault:get(link.target)
    if not file then
      return nil
    end
    link.target = file:url()
    remove_wikilink_class(link)
    return link
  end
end

--- Create a code block filter for executing Lua code blocks.
--- @param env table? Environment table for code execution (defaults to _G)
--- @param ... any Additional arguments to pass to executed code
--- @return fun(code: pandoc.CodeBlock): pandoc.CodeBlock|pandoc.Block|nil filter Code block filter function
local function make_codeblock_filter(env, ...)
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

return {
  callout_filter = callout_filter,
  make_codeblock_filter = make_codeblock_filter,
  make_image_filter = make_image_filter,
  make_link_filter = make_link_filter,
}
