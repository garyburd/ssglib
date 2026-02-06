---
permalink: paths/
---

# Paths

The `ssglib.paths` module provides file path conversion utilities and filesystem operations.

```lua
local paths = require "ssglib.paths"
```

## posix_path(s)

Convert a system path to POSIX format by replacing the system separator with `/`. On POSIX systems, this is a no-op.

```lua
paths.posix_path("articles\\hello.md")  -- "articles/hello.md"
```

## system_path(s)

Convert a POSIX path to the system-native separator format.

```lua
paths.system_path("articles/hello.md")  -- "articles\\hello.md" (on Windows)
```

## is_local_path(url)

Check whether a URL is a local vault path. URLs with a scheme (`http://`, `file://`, etc.) or host prefix (`//`) are not local.

```lua
paths.is_local_path("Hello World")       -- true
paths.is_local_path("https://example.com")  -- false
paths.is_local_path("//cdn.example.com")    -- false
```

## file_mtime(path)

Return the modification time of a file as an ISO 8601 string. Returns `""` if the file does not exist.

```lua
paths.file_mtime("vault/index.md")  -- "2025-01-15T10:30:00Z"
```

## walk_tree(root, fn)

Recursively walk a directory tree, calling `fn(path)` for each file. Directories and files starting with `.` are skipped.

```lua
paths.walk_tree("vault", function(path)
  print(path)
end)
```
