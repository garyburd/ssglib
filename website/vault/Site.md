---
permalink: site/
---

# Site

The `ssglib.site` module manages the output directory for a static site. It tracks which files are written, skips unchanged files, and can clean up stale output.

```lua
local site = require "ssglib.site"
```

## Site.new(root)

Create a new site rooted at `root`. The directory is created if it does not exist.

```lua
local s = site.Site.new("docs")
```

## Site:prepare(url)

Prepare to write a file at the given URL. Creates parent directories as needed. URLs ending with `/` are mapped to `index.html`. Returns the file system path of the output file.

```lua
local path = s:prepare("/articles/hello/")
-- path is "docs/articles/hello/index.html"
```

## Site:write_data(url, data)

Write a string to the file at `url`. If the file already exists with the same content, the write is skipped.

```lua
s:write_data("/index.html", "<html>...</html>")
```

## Site:write_file(url, path, mtime)

Copy a file from `path` to the site at `url`. If the target is newer than the source (based on `mtime`), the copy is skipped.

```lua
s:write_file("/style.css", "src/style.css")
```

## Site:write_dir(url, root)

Recursively copy all files from the `root` directory to the site under `url`. Dotfiles are skipped.

```lua
s:write_dir("/", "static")
-- copies static/.nojekyll to docs/.nojekyll
```

## Site:cleanup()

Delete files in the output directory that were not written during this build. Prints a summary of total, updated, and deleted files.
