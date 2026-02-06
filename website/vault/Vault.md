---
permalink: vault/
---

# Vault

The `ssglib.vault` module reads an Obsidian vault directory, caches file metadata, and provides access to vault files.

```lua
local vault = require "ssglib.vault"
```

## Vault.load(vault_path, cache_path)

Load a vault from `vault_path`. File metadata is cached at `cache_path` to speed up subsequent builds. Only files whose modification time has changed are re-read.

```lua
local v = vault.Vault.load("vault", "docs/.cache.json")
```

## Vault:get(path)

Look up a file by its vault-relative path. The `.md` extension is optional for notes.

```lua
local f = v:get("Getting Started")  -- finds "Getting Started.md"
local f = v:get("images/photo.jpg")
```

Returns a `File` or `nil`.

## Vault:notes()

Return a `pandoc.List` of all note files in the vault.

```lua
for f in v:notes():iter() do
  print(f:title())
end
```

## File

A `File` represents a single file in the vault.

### Fields

- `path` – Vault-relative path in POSIX format (e.g., `"articles/Hello World.md"`)
- `file_path` – Absolute file system path
- `mtime` – Modification time in ISO 8601 format
- `properties` – Table of file metadata from front matter or image headers

### File:type()

Returns the file type: `"note"` for `.md` files, `"image"` for image files, or `"other"`.

### File:title()

Returns the file name without directory or extension.

```lua
-- For path "articles/Hello World.md"
f:title()  -- "Hello World"
```

### File:url()

Returns the URL for the file. If the front matter includes a `permalink` property, that value is used. Otherwise, the URL is derived from the path with spaces replaced by hyphens.

```lua
-- With permalink: "hello/"
f:url()  -- "/hello/"

-- Without permalink, path "articles/Hello World.md"
f:url()  -- "/articles/Hello-World/"
```

### File:doc()

Parse the file and return a `pandoc.Doc`. Obsidian-style image wikilinks (`![[image.png]]`) are converted to standard Pandoc `Image` elements.

## format_date(fmt, date)

Format an ISO 8601 date string using `os.date` format specifiers.

```lua
vault.format_date("%B %Y", "2025-03-15")  -- "March 2025"
```
