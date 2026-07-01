--- Path and filesystem utilities.
--- Dependencies: Pandoc

local pandoc = require "pandoc"

--- Path and filesystem utilities.
---@class ssglib.paths
local M = {}

-- ============================================================================
-- File Path Utilities
-- ============================================================================

--- Create a path-separator converter.
---@param from string Separator to replace (e.g., "\\" or "/")
---@param to string Replacement separator (e.g., "/" or "\\")
---@return fun(s: string): string converter Path-separator converter
local function change_path_separator(from, to)
  if from == to then
    return function(s)
      return s
    end
  end
  return function(s)
    local result = s:gsub(from, to)
    return result
  end
end

--- Convert system paths to POSIX paths.
---@type fun(s: string): string
M.posix_path = change_path_separator(pandoc.path.separator, "/")

--- Convert POSIX paths to system-native paths.
---@type fun(s: string): string
M.system_path = change_path_separator("/", pandoc.path.separator)

--- Return a POSIX path's filename without its directory or extension.
---@param path string POSIX file path
---@return string stem
function M.stem(path)
  local s = (path:find("/[^/]*$") or 0) + 1
  local e = (path:find("%.[^.]*$") or #path + 1) - 1
  -- Ignore dots in directory components (`e < s`).
  if e < s then
    e = #path
  end
  return path:sub(s, e)
end

--- Check whether a URL is a vault path.
--- URLs with a scheme or host are external.
---@param url string URL to check
---@return boolean
function M.is_local_path(url)
  -- Schemes include `http:`, `mailto:`, `tel:`, and `file:`; hosts start `//`.
  return not (url:find("^%w[%w+.-]*:") or url:find("^//"))
end

-- ============================================================================
-- File System Operations
-- ============================================================================

--- Return a file's modification time.
---@param path string File path
---@return string time ISO 8601 timestamp, or "" if absent
local function file_mtime(path)
  local ok, mtime = pcall(pandoc.system.times, path)
  if not ok then
    return ""
  end
  return mtime
end

--- Return a file's size in bytes.
--- Seeks instead of reading, keeping large files inexpensive.
---@param path string File path
---@return integer size Bytes, or -1 if unreadable
local function file_size(path)
  local fh = io.open(path, "rb")
  if not fh then
    return -1
  end
  local size = fh:seek("end")
  fh:close()
  return size or -1
end

--- Check whether a file is readable.
---@param path string File path
---@return boolean
function M.file_exists(path)
  local fh = io.open(path, "rb")
  if not fh then
    return false
  end
  fh:close()
  return true
end

--- Check whether a path is a symbolic link.
---@param path string File path
---@return boolean
function M.is_symlink(path)
  -- Unlike its file and directory checks, Pandoc's symlink check raises for
  -- absent paths; normalize that case to false.
  local ok, result = pcall(pandoc.path.exists, path, "symlink")
  return ok and result
end

--- File metadata used for change detection: byte size and modification time.
--- This mirrors the subset of OS `stat(2)` unavailable through Pandoc. Equal
--- stats imply unchanged content without hashing. Missing files have size -1
--- and mtime "".
---@class Stat
---@field size integer Size in bytes, or -1 if the file does not exist
---@field mtime string Modification time (ISO 8601), or "" if the file does not exist

--- Snapshot a file's size and modification time.
---@param path string File path
---@return Stat
function M.stat(path)
  return { size = file_size(path), mtime = file_mtime(path) }
end

--- Walk a directory tree, calling a function for each leaf.
--- Symbolic links are leaves and are never followed. Unless `include_hidden`
--- is true, dot-prefixed files and directories are skipped.
---@param root string Root directory
---@param fn fun(path: string, is_symlink: boolean): nil Called for each file or symbolic link
---@param include_hidden boolean|nil Include dot-prefixed paths
function M.walk_tree(root, fn, include_hidden)
  local stack = { root }
  while true do
    local dir = table.remove(stack)
    if not dir then
      return
    end
    local success, names = pcall(pandoc.system.list_directory, dir)
    if not success then
      io.stderr:write(string.format("could not read directory: %s\n", dir))
    else
      for _, name in ipairs(names) do
        if include_hidden or name:sub(1, 1) ~= "." then
          local path = pandoc.path.join { dir, name }
          local is_symlink = M.is_symlink(path)
          if is_symlink then
            fn(path, true)
          elseif pandoc.path.exists(path, "directory") then
            table.insert(stack, path)
          else
            fn(path, false)
          end
        end
      end
    end
  end
end

--- Remove empty directories beneath `root`, deepest first.
--- Never remove `root` itself.
---@param root string Root directory
function M.remove_empty_dirs(root)
  local ok, names = pcall(pandoc.system.list_directory, root)
  if not ok then
    return
  end
  for _, name in ipairs(names) do
    local path = pandoc.path.join { root, name }
    if not M.is_symlink(path) and pandoc.path.exists(path, "directory") then
      M.remove_empty_dirs(path)
      local ok2, remaining = pcall(pandoc.system.list_directory, path)
      if ok2 and #remaining == 0 then
        pandoc.system.remove_directory(path)
      end
    end
  end
end

-- ============================================================================
-- Module Exports
-- ============================================================================

M._test = {
  change_path_separator = change_path_separator,
}

return M
