--- Manage a static site's output directory.
--- Dependencies: Pandoc

local parent = (...):match("(.-%.).+$") or ""
local paths = require(parent .. "paths")

local pandoc = require "pandoc"

local function info(format, ...)
  io.stdout:write(string.format(format .. "\n", ...))
end

-- Disposable build-cache manifest in the site root. Deployments should
-- exclude it (e.g. `aws s3 sync --exclude .ssglib-cache.json`).
local CACHE_NAME = ".ssglib-cache.json"

--- Load a site's cache manifest.
---@param path string Cache file path
---@return table cache Decoded cache, or an empty table on failure
local function load_cache(path)
  local ok, data = pcall(pandoc.system.read_file, path)
  if not ok then
    return {}
  end
  local ok2, decoded = pcall(pandoc.json.decode, data, false)
  if ok2 and type(decoded) == "table" then
    return decoded
  end
  return {}
end

--- Conservatively minify CSS without altering strings or syntax.
--- One left-to-right scan removes `/* */` comments and stashes escaped string
--- literals. It then collapses whitespace while preserving spaces required by
--- shorthand values, `calc()`, selector combinators except `>`, and strings.
---@param css string CSS source
---@return string css Minified CSS
local function minify_css(css)
  -- Stash strings and drop comments before changing whitespace.
  local strings = {}
  local out = {}
  local i, n = 1, #css
  while i <= n do
    local c = css:sub(i, i)
    if css:sub(i, i + 1) == "/*" then
      local e = css:find("*/", i + 2, true)
      i = e and (e + 2) or (n + 1)
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= n do
        local cj = css:sub(j, j)
        if cj == "\\" then
          j = j + 2
        elseif cj == c then
          break
        else
          j = j + 1
        end
      end
      strings[#strings + 1] = css:sub(i, math.min(j, n))
      out[#out + 1] = "\1" .. #strings .. "\1"
      i = j + 1
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  css = table.concat(out)

  css = css:gsub("%s+", " ") -- collapse whitespace runs
  -- Trim structural punctuation. Keep `+ - * /` spacing for `calc()`.
  css = css:gsub(" ?([{};,>]) ?", "%1")
  css = css:gsub(": ", ":") -- declaration or media-feature colon
  css = css:gsub(";}", "}") -- final block semicolon
  css = css:gsub("^ ", ""):gsub(" $", "")

  return (css:gsub("\1(%d+)\1", function(n)
    return strings[tonumber(n)]
  end))
end

--- Minify JavaScript by line when provably safe; otherwise return it unchanged.
--- Backticks, `/*`, and string-continuation backslashes can span lines, so any
--- of them disables the transform. Otherwise, remove full-line comments and
--- blank lines, trim line edges, and preserve all remaining newlines for
--- automatic semicolon insertion. Inline whitespace and `//` remain because
--- distinguishing them from string content requires a lexer.
---@param js string JavaScript source
---@return string js Minified or unchanged JavaScript source
local function prepare_js(js)
  if js:find("`", 1, true) or js:find("/*", 1, true) or js:find("\\\r?\n") then
    return js
  end
  local out = {}
  -- Append a newline to terminate the final line; discard any empty result.
  for line in (js .. "\n"):gmatch("(.-)\r?\n") do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 2) ~= "//" then
      out[#out + 1] = line
    end
  end
  return table.concat(out, "\n")
end

--- Manage a static site's output directory.
---@class ssglib.Site
---@field dir string Output root
---@field prefix string URL path prefix (e.g., "/" or "/ssglib/")
---@field files table<string, boolean> Accessed file paths
---@field claimed table<string, string> Case-folded file paths mapped to claiming URLs
---@field updated integer Number of files updated in the site
---@field total integer Total files written to the site
---@field cache_path string Path to the cache manifest
---@field cache table<string, {size: integer, mtime: string, value: any}> Persisted per-file cache
---@field seen table<string, boolean> Cache keys touched during this build
local Site = {}
Site.__index = Site

--- Create a site.
---@param dir string Output root
---@param prefix string | nil URL path prefix (default "/"), must start and end with "/"
---@return ssglib.Site site New site
function Site.new(dir, prefix)
  prefix = prefix or "/"
  assert(prefix:sub(1, 1) == "/" and prefix:sub(-1) == "/", "prefix must start and end with /")
  local cache_path = pandoc.path.join { dir, CACHE_NAME }
  local site = setmetatable({
    dir = dir,
    prefix = prefix,
    files = {},
    claimed = {},
    updated = 0,
    total = 0,
    cache_path = cache_path,
    cache = load_cache(cache_path),
    seen = {},
  }, Site)
  pandoc.system.make_directory(site.dir, true)
  -- Keep cleanup from deleting the manifest.
  site.files[cache_path] = true
  return site
end

--- Memoize a value against a source file's stat.
--- The cache persists across builds and recomputes only when size or mtime
--- changes. Passing the stat lets one source snapshot drive other freshness
--- checks, such as `write_file`. Nil results are also cached.
---@generic T
---@param key string Stable key, such as a vault-relative path
---@param stat Stat Current stat of the source
---@param compute fun(): T Function to compute the value on a cache miss
---@return T value Cached or computed value
function Site:cached(key, stat, compute)
  self.seen[key] = true
  local entry = self.cache[key]
  -- Matching size and mtime indicate a hit.
  if entry and entry.size == stat.size and entry.mtime == stat.mtime then
    return entry.value
  end
  local value = compute()
  -- Persist only compared stat fields.
  self.cache[key] = { size = stat.size, mtime = stat.mtime, value = value }
  return value
end

--- Prepare the output file for a URL and create its directories.
--- Reject traversal outside the root and conflicting URLs. File targets are
--- case-insensitive to match common filesystems such as APFS and NTFS.
--- Return the output file's system path.
---@param url string Absolute URL path
---@return string path File system path
function Site:prepare(url)
  assert(getmetatable(self) == Site)
  local requested_url = url
  url = url:gsub("/$", "/index.html")
  assert(url:sub(1, #self.prefix) == self.prefix, "url must start with prefix")
  url = url:sub(#self.prefix + 1)

  -- After removing the site prefix, reject POSIX traversal, Windows
  -- separators, and colons that Windows treats as a replacement drive.
  assert(url ~= "", "url must identify a file")
  assert(not url:find("\\", 1, true), "url must use forward slashes")
  assert(not url:find(":", 1, true), "url must not contain a colon")
  assert(not url:find("//", 1, true), "url must not contain empty path segments")
  local system_url = paths.system_path(url)
  assert(not pandoc.path.is_absolute(system_url), "url must remain relative after prefix")
  for segment in url:gmatch("[^/]+") do
    assert(segment ~= "." and segment ~= "..", "url must not contain . or .. path segments")
  end

  local path = pandoc.path.join { self.dir, paths.system_path(url) }
  self.total = self.total + 1
  local claim = path:lower()
  local prev = self.claimed[claim]
  if prev then
    error(string.format("duplicate write to %s (already claimed by %s)", requested_url, prev))
  end
  self.claimed[claim] = requested_url
  self.files[path] = true
  pandoc.system.make_directory(pandoc.path.directory(path), true)
  return path
end

--- Write data to a URL.
---@param url string Absolute URL path
---@param data string Content to write to file
function Site:write_data(url, data)
  local target = self:prepare(url)
  local ok, old_data = pcall(pandoc.system.read_file, target)
  if ok and (old_data == data) then
    return
  end
  self.updated = self.updated + 1
  pandoc.system.write_file(target, data)
end

--- Join and minify CSS sources, then write them to a URL.
--- Return the target with a content-derived `?v=<hash>` query.
---@param url string Absolute URL path
---@param ... string CSS sources, joined in order with newlines
---@return string url Target with a content-hash query
function Site:write_css(url, ...)
  local css = minify_css(table.concat({ ... }, "\n"))
  self:write_data(url, css)
  return string.format("%s?v=%s", url, pandoc.utils.sha1(css))
end

--- Join and minify JavaScript sources, then write them to a URL.
--- Return the target with a content-derived `?v=<hash>` query.
---@param url string Absolute URL path
---@param ... string JavaScript sources, joined in order with newlines
---@return string url Target with a content-hash query
function Site:write_js(url, ...)
  local sources = {}
  for i, source in ipairs({ ... }) do
    sources[i] = prepare_js(source)
  end
  local js = table.concat(sources, "\n")
  self:write_data(url, js)
  return string.format("%s?v=%s", url, pandoc.utils.sha1(js))
end

--- Copy a file to a URL unless the target is newer.
---@param url string Absolute URL path
---@param path string File path
---@param stat Stat|nil Precomputed source stat (read from disk if omitted)
---@return boolean updated Whether the file was copied
function Site:write_file(url, path, stat)
  stat = stat or paths.stat(path)
  local target = self:prepare(url)
  local tstat = paths.stat(target)
  -- Like `aws s3 sync`, skip matching sizes only when the destination is newer.
  -- Same-size edits without a newer mtime are missed. `pandoc.system.copy`
  -- gives fresh copies the current time, making them newer than their sources.
  if tstat.mtime > stat.mtime and tstat.size == stat.size then
    return false
  end
  self.updated = self.updated + 1
  pandoc.system.copy(path, target)
  return true
end

--- Copy a directory to a URL, skipping dot-prefixed paths.
--- Copy file symlinks; warn and skip directory symlinks.
---@param url string Absolute URL path ending with "/"
---@param root string Directory path
function Site:write_dir(url, root)
  assert(url:sub(-1) == "/")
  paths.walk_tree(root, function(path, is_symlink)
    if is_symlink and pandoc.path.exists(path, "directory") then
      io.stderr:write(string.format("ssglib: not following directory symlink: %s\n", path))
      return
    end
    local u = url .. paths.posix_path(pandoc.path.make_relative(path, root))
    self:write_file(u, path)
  end)
end

--- Persist only cache entries touched by this build.
---@private
function Site:save_cache()
  local pruned = {}
  for path in pairs(self.seen) do
    pruned[path] = self.cache[path]
  end
  self.cache = pruned
  pandoc.system.write_file(self.cache_path, pandoc.json.encode(self.cache))
end

--- Remove unused output files. Remove symlinks as leaves without following them.
function Site:cleanup()
  assert(getmetatable(self) == Site)
  self:save_cache()
  local deleted = 0
  paths.walk_tree(self.dir, function(path)
    if not self.files[path] then
      info("DELETE /%s", paths.posix_path(pandoc.path.make_relative(path, self.dir)))
      deleted = deleted + 1
      pandoc.system.remove(path)
    end
  end, true)
  paths.remove_empty_dirs(self.dir)
  info("Site:  total=%d, updated=%d, deleted=%d", self.total, self.updated, deleted)
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return {
  Site = Site,
  _test = {
    minify_css = minify_css,
    prepare_js = prepare_js,
  },
}
