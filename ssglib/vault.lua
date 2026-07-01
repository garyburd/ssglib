--- Read a vault of notes.
--- Dependencies: Pandoc

local parent = (...):match("(.-%.).+$") or ""
local paths = require(parent .. "paths")
local pandoc = require "pandoc"
local stringify = pandoc.utils.stringify

--- Format an ISO 8601 date with a strftime specification.
---@param fmt string Format
---@param date string ISO 8601 date
---@return string
local function format_date(fmt, date)
  local year, month, day = date:match("(%d%d%d%d)-(%d%d)-(%d%d)")
  -- `os.time` uses local time and defaults to noon, so UTC formats (`!`) keep
  -- the date in every real-world time zone (within ±12 hours).
  local s = os.date(fmt, os.time { year = year, month = month, day = day })
  ---@type string
  return s
end

-- ============================================================================
-- Pandoc Document Utilities
-- ============================================================================

--- Pandoc format for notes with wikilinks and YAML front matter.
--- `hard_line_breaks` is omitted: although Obsidian renders soft breaks as
--- `<br>`, enabling it would alter multiline paragraphs.
---@type string
local note_format = table.concat({
  "commonmark",
  "+autolink_bare_uris",
  "+fenced_divs",
  "+footnotes",
  "+pipe_tables",
  "+strikeout",
  "+task_lists",
  "+tex_math_dollars",
  "+wikilinks_title_after_pipe",
  "+yaml_metadata_block",
})

--- Replace `Str` ending in "!" plus `Link` with `Image`.
--- Pandoc parses `![[image.png]]` as `Str("!")` plus a `wikilink` `Link`.
--- Attached text (`text![[image.png]]`) becomes `Str("text!")`, so any
--- trailing "!" marks the next wikilink as an embed.
local function image_link_filter(inlines)
  local result = nil
  local scan, len = 1, #inlines
  for fill = 1, len do
    local curr = inlines[scan]
    if scan < len and curr.tag == "Str" and curr.text:sub(-1) == "!" then
      local next = inlines[scan + 1]
      if next.tag == "Link" and next.classes:includes("wikilink") then
        local content = ""
        if stringify(next.content) ~= next.target then
          content = next.content
        end
        -- TODO: Support Obsidian size hints. The pipe value in
        -- `![[image.png|300]]` or `![[image.png|300x200]]` sets the display
        -- dimensions, but here it becomes alt text and `make_image_filter`
        -- later replaces the dimensions.
        local image = pandoc.Image(content, next.target, next.title or "")
        if curr.text == "!" then
          curr = image
          scan = scan + 1 -- skip the Link, now consumed into the Image
        else
          -- Keep text before "!"; the next iteration copies the replacement.
          curr = pandoc.Str(curr.text:sub(1, -2))
          inlines[scan + 1] = image
        end
        result = inlines
      end
    end
    inlines[fill] = curr
    scan = scan + 1
  end
  return result
end

-- ============================================================================
-- Frontmatter Utilities
-- ============================================================================

--- Read a file's YAML `permalink`.
---@param filepath string Full filesystem path
---@return string|nil permalink Value, or nil if absent
local function read_permalink(filepath)
  local fh = io.open(filepath, "r")
  if not fh then
    return nil
  end
  local permalink
  local found = false
  -- `read("l")` keeps CR from CRLF; strip it before matching.
  local first = (fh:read("l") or ""):gsub("\r$", "")
  if first == "---" then
    for line in fh:lines() do
      line = line:gsub("\r$", "")
      if line == "---" then
        found = true
        break
      end
      if not permalink then
        local value = line:match("^permalink:%s*(.-)%s*$")
        if value then
          -- Strip matching single or double quotes.
          permalink = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
        end
      end
    end
  end
  fh:close()
  if found then
    return permalink
  end
  return nil
end

-- ============================================================================
-- Vault Class
-- ============================================================================

--- Obsidian vault.
---@class ssglib.Vault
---@field dir string Root directory path of the vault
---@field prefix string URL path prefix (e.g., "/" or "/ssglib/")
---@field notes pandoc.List Note paths
---@field _permalinks table<string, string> Note paths mapped to permalinks
---@field _paths table<string, boolean> Set of all vault file paths (for link resolution)
local Vault = {}
Vault.__index = Vault

--- Scan a directory into a vault.
--- Index file symlinks normally; warn and skip directory symlinks.
---@param dir string Vault root
---@param prefix string | nil URL path prefix (default "/"), must start and end with "/"
---@return ssglib.Vault vault Indexed vault
function Vault.new(dir, prefix)
  prefix = prefix or "/"
  assert(prefix:sub(1, 1) == "/" and prefix:sub(-1) == "/", "prefix must start and end with /")
  local v = setmetatable({
    dir = dir,
    prefix = prefix,
    notes = pandoc.List(),
    _permalinks = {},
    _paths = {},
  }, Vault)
  paths.walk_tree(dir, function(filepath, is_symlink)
    if is_symlink and pandoc.path.exists(filepath, "directory") then
      io.stderr:write(string.format("ssglib: not following directory symlink: %s\n", filepath))
      return
    end
    local path = paths.posix_path(pandoc.path.make_relative(filepath, dir))
    v._paths[path] = true
    if path:sub(-#".md") == ".md" then
      v._permalinks[path] = read_permalink(filepath)
      v.notes:insert(path)
    end
  end)
  return v
end

--- Return the full filesystem path for a vault-relative POSIX path.
---@param path string Vault-relative POSIX path
---@return string system_path Full filesystem path
function Vault:system_path(path)
  return pandoc.path.join({ self.dir, paths.system_path(path) })
end

--- Resolve a link target to a vault-relative POSIX path.
--- Full paths work with or without `.md`. For duplicate bare filenames,
--- Obsidian apparently chooses the shortest path relative to the source; that
--- heuristic is unimplemented, and `source` is reserved for it.
---@param target string Link target to resolve
---@param source string Source path, reserved for bare-name resolution
---@return string|nil path Resolved path, or nil
function Vault:resolve(target, source)
  local _ = source -- unused for now.
  if self._paths[target] then
    return target
  end
  local md = target .. ".md"
  if self._paths[md] then
    return md
  end
  return nil
end

--- Return the URL for a vault-relative POSIX path.
---@param path string Vault-relative POSIX path (e.g. "articles/Hello World.md" or "images/photo.jpg")
---@return string url
function Vault:url(path)
  local url = self._permalinks[path]
  if not url then
    url = path:gsub("%.md$", "/"):gsub(" ", "-"):gsub("--+", "-")
  end
  url = self.prefix .. url
  -- Reject leading-slash permalinks, which yield protocol-relative URLs.
  assert(not url:find("//"), string.format("malformed url %q for %s", url, path))
  return url
end

--- Parse a file into a Pandoc document.
---@param path string Vault-relative POSIX path
---@return table pandoc.Doc
function Vault:doc(path)
  local doc = pandoc.read(pandoc.system.read_file(self:system_path(path)), note_format)
  doc = doc:walk { Inlines = image_link_filter }
  return doc
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return {
  Vault = Vault,
  format_date = format_date,
}
