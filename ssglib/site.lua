--- Manage output directory for static website generation.
--- Dependencies: Pandoc

local parent = (...):match("(.-%.).+$") or ""
local paths = require(parent .. "paths")

local pandoc = require "pandoc"

local function info(format, ...)
  io.stdout:write(string.format(format .. "\n", ...))
end

--- Manage output directory for static website generation.
--- @class Site
--- @field root string Root directory path for output
--- @field files table<string, boolean> Set of accessed file paths
--- @field updated integer Number of files updated in the site
--- @field total integer Total number of files written to site
local Site = {}
Site.__index = Site

--- Create a new Site instance.
--- @param root string Root directory path for output
--- @return Site site New site instance
function Site.new(root)
  local site = setmetatable({
    root = root,
    files = {},
    updated = 0,
    total = 0,
  }, Site)
  pandoc.system.make_directory(site.root, true)
  return site
end

--- Prepare write to file corresponding to the specified URL.
--- Output directories are created as needed.
--- Returns the file system path of the output file.
--- @param url string Absolute URL path
--- @return string path File system path
function Site:prepare(url)
  assert(getmetatable(self) == Site)
  self.total = self.total + 1
  url = url:gsub("/$", "/index.html")
  local path = pandoc.path.join { self.root, paths.system_path(url:sub(2)) }
  self.files[path] = true
  pandoc.system.make_directory(pandoc.path.directory(path), true)
  return path
end

--- Write data to target URL.
--- @param url string Absolute URL path
--- @param data string Content to write to file
function Site:write_data(url, data)
  local target = self:prepare(url)
  local ok, old_data = pcall(pandoc.system.read_file, target)
  if ok and (old_data == data) then
    return
  end
  self.updated = self.updated + 1
  pandoc.system.write_file(target, data)
end

---  Copy file at path to target URL.
---  Do nothing when target file is newer than the source.
--- @param url string Absolute URL path.
--- @param path string File path
--- @param mtime string|nil File modification time in ISO 8601 format
function Site:write_file(url, path, mtime)
  local target = self:prepare(url)
  if paths.file_mtime(target) > (mtime or paths.file_mtime(path)) then
    return
  end
  self.updated = self.updated + 1
  pandoc.system.copy(path, target)
end

---  Copy directory at path to target URL.
--- @param url string Absolute URL path ending with "/"
--- @param root string Directory path
function Site:write_dir(url, root)
  assert(url:find("/$"))
  paths.walk_tree(root, function(path)
    local u = url .. paths.posix_path(pandoc.path.make_relative(path, root))
    self:write_file(u, path)
  end)
end

---  Remove unused files from the site directory tree.
function Site:cleanup()
  assert(getmetatable(self) == Site)
  local deleted = 0
  paths.walk_tree(self.root, function(path)
    if not self.files[path] then
      info("DELETE /%s", paths.posix_path(pandoc.path.make_relative(path, self.root)))
      deleted = deleted + 1
      pandoc.system.remove(path)
    end
  end)
  info("Site:  total=%d, updated=%d, deleted=%d", self.total, self.updated, deleted)
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return {
  Site = Site,
}
