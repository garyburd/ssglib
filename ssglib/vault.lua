--- Library for reading an Obsidian vault.
--- Dependencies: Pandoc

local parent = (...):match("(.-%.).+$") or ""
local paths = require(parent .. "paths")
local pandoc = require "pandoc"
local stringify = pandoc.utils.stringify

local function warn(format, ...)
  io.stderr:write(string.format(format .. "\n", ...))
end

local function info(format, ...)
  io.stdout:write(string.format(format .. "\n", ...))
end

--- Format ISO 8601 date string using strftime format specification.
--- @param fmt string format
--- @param date string date in ISO 8601 format.
--- @return string
local function format_date(fmt, date)
  local year, month, day = date:match("(%d%d%d%d)-(%d%d)-(%d%d)")
  local s = os.date(fmt, os.time { year = year, month = month, day = day })
  ---@type string
  return s
end

-- ============================================================================
-- File Type Classification
-- ============================================================================

--- Map file extensions to their type.
--- @type table<string, string>
local file_types = {
  [".png"] = "image",
  [".jpeg"] = "image",
  [".jpg"] = "image",
  [".gif"] = "image",
  [".webp"] = "image",
  [".md"] = "note",
}

--- Get file type from file's extension.
--- The file types are "note", "image", "base" and other.
--- @param path string File path to classify
--- @return string type
local function file_type(path)
  local _, ext = pandoc.path.split_extension(path)
  return file_types[ext:lower()] or "other"
end

-- ============================================================================
-- Pandoc Document Utiltiies
-- ============================================================================

--- Pandoc format specification for parsing note files with wikilinks and YAML front matter.
--- @type string
local note_format = table.concat({
  "commonmark",
  "+wikilinks_title_after_pipe",
  "+yaml_metadata_block",
})

--- Replace Str("!") + Link() with Image()
--- Pandoc commonark parses Obsidian image wikilinks ![[image.png]]
--- as Str("!") + Link() with a "wikilink" class.
local function image_link_filter(inlines)
  local result = nil
  local scan, len = 1, #inlines
  for fill = 1, len do
    local curr = inlines[scan]
    if scan < len and curr.tag == "Str" and curr.text == "!" then
      local next = inlines[scan + 1]
      if next.tag == "Link" and next.classes:includes("wikilink") then
        local content = ""
        if stringify(next.content) ~= next.target then
          content = next.content
        end
        -- Replace current with image.
        curr = pandoc.Image(content, next.target, next.title or "")
        -- Skip link.
        scan = scan + 1
        -- Return modified list.
        result = inlines
      end
    end
    inlines[fill] = curr
    scan = scan + 1
  end
  return result
end

--- Find all internal links in a Pandoc document.
--- @param doc table Pandoc document
--- @return table links Sequence of links
local function find_local_links(doc)
  local links = {}
  doc:walk({
    Link = function(link)
      if paths.is_local_path(link.target) then
        table.insert(links, link.target)
      end
      return nil
    end,
    Image = function(img)
      if paths.is_local_path(img.src) then
        table.insert(links, img.src)
      end
      return nil
    end,
  })
  return links
end

-- ============================================================================
-- Images
-- ============================================================================

--- Parse JPEG dimensions from binary data string.
--- @param data string The JPEG data.
--- @return number|nil Width
--- @return number|nil Height
local function parse_jpeg_size(data)
  if not data or #data < 2 then
    return nil, nil
  end

  -- Check JPEG signature (FF D8)
  if data:byte(1) ~= 0xFF or data:byte(2) ~= 0xD8 then
    return nil, nil
  end

  local pos = 3 -- Start after signature

  -- Scan for SOF (Start of Frame) markers
  while pos < #data do
    -- Find next marker (FF XX)
    if data:byte(pos) ~= 0xFF then
      break
    end

    local marker = data:byte(pos + 1)
    if not marker then
      break
    end

    pos = pos + 2

    -- Check if this is a SOF marker
    -- SOF markers: C0-C3, C5-C7, C9-CB, CD-CF
    -- (excludes C4, C8, CC which are not SOF)
    local is_sof = (marker >= 0xC0 and marker <= 0xC3)
      or (marker >= 0xC5 and marker <= 0xC7)
      or (marker >= 0xC9 and marker <= 0xCB)
      or (marker >= 0xCD and marker <= 0xCF)

    if is_sof then
      -- SOF segment structure:
      -- 2 bytes: segment length
      -- 1 byte: precision
      -- 2 bytes: height
      -- 2 bytes: width
      if pos + 7 > #data then
        break
      end

      -- Skip length (2 bytes) and precision (1 byte)
      pos = pos + 3

      -- Read height (2 bytes, big-endian)
      local h1, h2 = data:byte(pos, pos + 1)
      local height = h1 * 256 + h2
      pos = pos + 2

      -- Read width (2 bytes, big-endian)
      local w1, w2 = data:byte(pos, pos + 1)
      local width = w1 * 256 + w2

      return width, height
    end

    -- Not a SOF marker, skip this segment
    -- Read segment length (2 bytes, big-endian)
    if pos + 1 > #data then
      break
    end
    local len1, len2 = data:byte(pos, pos + 1)
    local segment_length = len1 * 256 + len2

    if segment_length < 2 then
      break
    end

    -- Skip to next segment
    pos = pos + segment_length
  end

  -- No SOF marker found
  return nil, nil
end

--- Read width and height metadata from an image file.
--- @param path string Path to the image file
--- @return table properties Table with width and height fields
local function read_image_properties(path)
  local data = pandoc.system.read_file(path)

  -- The pandoc.image.size function is slow compared to the
  -- AI generated parse_jpeg_size function.
  -- Try to get the size with a pure-Lua function first. Fallback
  -- to the Pandoc function.
  local width, height = parse_jpeg_size(data)
  if not width or not height then
    local ok, size = pcall(pandoc.image.size, data)
    if not ok then
      return {}
    end
    width = size.width
    height = size.height
  end

  return {
    width = width,
    height = height,
  }
end

-- ============================================================================
-- File Metadata
-- ============================================================================

--- Read metadata from a markdown note file.
--- @param path string Path to the note file
--- @return table properties Front matter metadata as Lua table
local function read_note_properties(path)
  local doc = pandoc.read(pandoc.system.read_file(path), note_format)
  local meta = doc.meta
  local props = {}
  if meta.permalink then
    props.permalink = stringify(meta.permalink):gsub("^/+", "")
  end
  if meta.hide and stringify(meta.hide) == "true" then
    props.hide = true
  end
  if meta.date then
    props.date = pandoc.utils.normalize_date(stringify(meta.date))
  end
  if meta.tags and type(meta.tags) == "table" then
    props.tags = meta.tags:map(stringify)
  end
  props.links = find_local_links(doc)
  return props
end

--- Maps file types to their corresponding property reader functions
--- @type table<string, fun(path: string): table>
local property_readers = {
  image = read_image_properties,
  note = read_note_properties,
}

--- Read file-type-specific properties (metadata) from a file.
--- Returns empty table for unrecognized file types.
--- @param path string Path to the file
--- @return table properties File metadata/properties
local function read_file_metadata(path)
  local reader = property_readers[file_type(path)]
  if not reader then
    return {}
  end
  return reader(path)
end

-- ============================================================================
-- File Class
-- ============================================================================

--- Represents a file in the vault with its path, modification time, and metadata.
--- @class File
--- @field path string Relative path from vault root (POSIX format)
--- @field file_path string File system path
--- @field base string URL base path (e.g., "/" or "/ssglib/")
--- @field mtime string File modification timestamp in ISO 8601 format
--- @field properties table File-specific metadata (e.g., YAML front matter, image dimensions)
local File = {}
File.__index = File

--- Get the type classification of this file.
--- @return string type Returns "image", "note", or "other"
function File:type()
  assert(getmetatable(self) == File)
  return file_type(self.path)
end

--- Get the file's title.
--- @return string title
function File:title()
  assert(getmetatable(self) == File)
  -- Find position after the last slash (or start of string if no slash)
  local s = self.path:match("^.*/()") or 1
  -- Find position of the last dot before end of string (or end+1 if no dot)
  local e = (self.path:match("()%.[^.]*$") or (#self.path + 1)) - 1
  return self.path:sub(s, e)
end

--- Get the URL for the file.
--- @return string url
function File:url()
  assert(getmetatable(self) == File)
  local url = self.properties.permalink
  if not url then
    url = self.path:gsub(".md$", "/"):gsub(" ", "-"):gsub("--+", "-")
  end
  assert(not url:find("//"))
  return self.base .. url
end

--- Parse document from file
--- @return table pandoc.Doc
function File:doc()
  assert(getmetatable(self) == File)
  local doc = pandoc.read(pandoc.system.read_file(self.file_path), note_format)
  doc = doc:walk { Inlines = image_link_filter }
  return doc
end

-- ============================================================================
-- Vault Cache
-- ============================================================================

--- Cache file schema version number.
--- Increment this when the cache file format changes to invalidate old caches.
--- @type integer
local cache_schema = 3

--- Read cached file metadata from disk.
--- Returns empty table if cache doesn't exist, is invalid, or has wrong schema version.
--- @param path string|nil Path to cache file, or nil to return empty cache
--- @return table<string, File> files Dictionary mapping file paths to File objects
local function read_metadata_cache(path)
  local ok, data = pcall(pandoc.system.read_file, path)
  if not ok then
    return {}
  end
  local ok2, cache = pcall(pandoc.json.decode, data, false)
  if not ok2 then
    warn("error reading cache %s: %s", path, cache)
    return {}
  end
  if type(cache) ~= "table" or cache.schema ~= cache_schema or type(cache.files) ~= "table" then
    warn("error reading cache %s: bad file format", path)
    return {}
  end
  local cache_files = {}
  for _, f in pairs(cache.files) do
    cache_files[f.path] = setmetatable(f, File)
  end
  return cache_files
end

--- Write file metadata cache to disk.
--- @param path string Path where cache file should be written
--- @param files table<string, File> Dictionary of File objects to cache
local function write_metadata_cache(path, files)
  local file, err = io.open(path, "w+")
  if not file then
    warn("Failed to write cache: %s", err)
    return
  end
  -- Add line breaks between files to aid debugging.
  file:write(string.format('{"schema": %d, "files": [\n', cache_schema))
  local first = true
  for _, f in pairs(files) do
    if first then
      first = false
    else
      file:write(",\n")
    end
    file:write(pandoc.json.encode({ path = f.path, mtime = f.mtime, properties = f.properties }))
  end
  file:write("\n]}")
  file:close()
end

-- ============================================================================
-- Vault Class
-- ============================================================================

--- Represents a vault (collection of files).
--- @class Vault
--- @field path string Root directory path of the vault
--- @field base string URL base path (e.g., "/" or "/ssglib/")
--- @field files table<string, File> Dictionary mapping relative paths to File objects.
--- @field _notes_list pandoc.List | nil Sequence of files.
local Vault = {}
Vault.__index = Vault

--- Create and load a vault by scanning files and reading metadata cache.
--- @param vault_path string Root directory of the vault
--- @param cache_path string  | nil Path to metadata cache file
--- @param base string | nil URL base path (default "/"), must start and end with "/"
--- @return Vault vault Loaded vault with all files scanned
function Vault.load(vault_path, cache_path, base)
  assert(vault_path)
  base = base or "/"
  assert(base:sub(1, 1) == "/" and base:sub(-1) == "/", "base must start and end with /")
  local v = setmetatable({}, Vault)
  v.path = vault_path
  v.base = base
  v.files = {}
  v:_scan(cache_path)
  return v
end

--- Scan vault directory and update file metadata.
--- Uses cache for unchanged files, re-read metadata for modified files.
--- @param cache_path string | nil Path to metadata cache file
function Vault:_scan(cache_path)
  local files = cache_path and read_metadata_cache(cache_path) or {}
  local total, updated = 0, 0
  paths.walk_tree(self.path, function(file_path)
    local path = paths.posix_path(pandoc.path.make_relative(file_path, self.path))
    local mtime = paths.file_mtime(file_path)
    local file = files[path]
    total = total + 1
    if file and file.mtime == mtime then
      file.file_path = file_path
      file.base = self.base
      self.files[path] = setmetatable(file, File)
      return
    end
    local properties = read_file_metadata(file_path)
    updated = updated + 1
    self.files[path] = setmetatable({
      path = path,
      file_path = file_path,
      base = self.base,
      mtime = mtime,
      properties = properties,
    }, File)
  end)
  if cache_path then
    write_metadata_cache(cache_path, self.files)
  end
  info("Vault: total=%d, updated=%d", total, updated)
end

--- Look up a file in the vault by its vault relative POSIX path.
--- @param path string Relative path to look up (may or may not include extension)
--- @return File|nil file The file if found, nil otherwise
function Vault:get(path)
  assert(getmetatable(self) == Vault)
  local file = self.files[path]
  if file then
    return file
  end
  return self.files[path .. ".md"]
end

--- Query vault files.
--- @return pandoc.List files notes
function Vault:notes()
  if not self._notes_list then
    local notes = {}
    for _, f in pairs(self.files) do
      if f:type() == "note" then
        table.insert(notes, f)
      end
    end
    self._notes_list = pandoc.List(notes)
  end
  return self._notes_list
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return {
  Vault = Vault,
  format_date = format_date,
}
