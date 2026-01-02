--- File Path and File System Utilities
--- Dependencies: Pandoc

local pandoc = require "pandoc"

-- ============================================================================
-- File Path Utilities
-- ============================================================================

--- Create a function that replaces path separators from one format to another.
--- @param from string The separator to replace (e.g., "\\" or "/")
--- @param to string The separator to replace with (e.g., "/" or "\\")
--- @return fun(s: string): string converter Function that converts separators in a path string
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

--- Convert system paths to POSIX format (forward slashes).
--- @type fun(s: string): string
local posix_path = change_path_separator(pandoc.path.separator, "/")

--- Convert POSIX paths to system-native format.
--- @type fun(s: string): string
local system_path = change_path_separator("/", pandoc.path.separator)

--- Check whether URL is a path in the vault.
--- Any URL containing a scheme (http://, file://, etc.) or
--- host is considered external.
--- @param url string The URL to check
--- @return boolean
local function is_local_path(url)
  -- Check for protocol (http://, https://, ftp://, file://, etc.)
  -- Check for host (starts with //)
  return not (url:find("^%w+://") or url:find("^//"))
end

-- ============================================================================
-- File System Operations
-- ============================================================================

---  Retrieve the last modification time of a file.
--- @param path string file path
--- @return string time in ISO 8601 format or "" if no file
local function file_mtime(path)
  local ok, mtime = pcall(pandoc.system.times, path)
  if not ok then
    return ""
  end
  return mtime
end

--- Recursively walks a directory tree and calls a function for each file.
--- Skips files and directories whose names start with ".".
--- @param root string Root directory path to start walking from
--- @param fn fun(path: string): nil Callback function invoked for each file with its full path
local function walk_tree(root, fn)
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
        if not name:find("^%.") then
          local path = pandoc.path.join { dir, name }
          if pandoc.path.exists(path, "directory") then
            table.insert(stack, path)
          else
            fn(path)
          end
        end
      end
    end
  end
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return {
  _test = {
    change_path_separator = change_path_separator,
  },
  posix_path = posix_path,
  system_path = system_path,
  walk_tree = walk_tree,
  file_mtime = file_mtime,
  is_local_path = is_local_path,
}
