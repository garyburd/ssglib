# ssglib

Lua library for building static websites from
[Obsidian](https://obsidian.md) vaults with
[Pandoc](https://pandoc.org).

Features:

- Read Obsidian vaults with front matter and wikilinks
- Resolve wikilinks and wrap image-led paragraphs as figures
- Build HTML and XML programmatically
- Update output directories incrementally

`docgen/main.lua` generates this file. Edit `docgen/template.md` or the
source doc comments, not this file.

## Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Minimal main.lua](#minimal-mainlua)
  - [Build Pipeline](#build-pipeline)
- [Vault](#vault)
  - [Vault.new(dir, prefix)](#vaultnewdir-prefix)
  - [Vault:system_path(path)](#vaultsystem_pathpath)
  - [Vault:resolve(target, source)](#vaultresolvetarget-source)
  - [Vault:url(path)](#vaulturlpath)
  - [Vault:doc(path)](#vaultdocpath)
- [Site](#site)
  - [Site.new(dir, prefix)](#sitenewdir-prefix)
  - [Site:cached(key, stat, compute)](#sitecachedkey-stat-compute)
  - [Site:prepare(url)](#siteprepareurl)
  - [Site:write_data(url, data)](#sitewrite_dataurl-data)
  - [Site:write_css(url)](#sitewrite_cssurl)
  - [Site:write_js(url)](#sitewrite_jsurl)
  - [Site:write_file(url, path, stat)](#sitewrite_fileurl-path-stat)
  - [Site:write_dir(url, root)](#sitewrite_dirurl-root)
  - [Site:cleanup()](#sitecleanup)
- [Elements](#elements)
  - [elements.render(value)](#elementsrendervalue)
  - [elements.concat(t, sep)](#elementsconcatt-sep)
  - [elements.raw](#elementsraw)
  - [elements.html](#elementshtml)
  - [elements.xml](#elementsxml)
- [Filters](#filters)
  - [filters.figure_filter(para)](#filtersfigure_filterpara)
  - [filters.gallery_filter(div)](#filtersgallery_filterdiv)
  - [filters.make_image_filter(vault, site, source)](#filtersmake_image_filtervault-site-source)
  - [filters.make_link_filter(vault, source)](#filtersmake_link_filtervault-source)
  - [filters.make_codeblock_filter(env)](#filtersmake_codeblock_filterenv)
- [Paths](#paths)
  - [paths.posix_path(s)](#pathsposix_paths)
  - [paths.system_path(s)](#pathssystem_paths)
  - [paths.stem(path)](#pathsstempath)
  - [paths.is_local_path(url)](#pathsis_local_pathurl)
  - [paths.file_exists(path)](#pathsfile_existspath)
  - [paths.is_symlink(path)](#pathsis_symlinkpath)
  - [paths.stat(path)](#pathsstatpath)
  - [paths.walk_tree(root, fn, include_hidden)](#pathswalk_treeroot-fn-include_hidden)
  - [paths.remove_empty_dirs(root)](#pathsremove_empty_dirsroot)
- [RSS](#rss)
  - [rss.head_link(url, channel)](#rsshead_linkurl-channel)
  - [rss.write_rss(site, vault, url, channel, items)](#rsswrite_rsssite-vault-url-channel-items)
- [Gallery](#gallery)
  - [gallery.css()](#gallerycss)
  - [gallery.js()](#galleryjs)

## Getting Started

Build a static site from an Obsidian vault with ssglib and Pandoc.

### Prerequisites

- [Pandoc](https://pandoc.org/installing.html) with Lua support
  (`pandoc-lua`)
- An Obsidian vault with markdown files

### Minimal main.lua

Minimal site builder:

``` lua
local pandoc = require "pandoc"
local elements = require "ssglib.elements"
local paths = require "ssglib.paths"
local vault = require "ssglib.vault"
local site = require "ssglib.site"
local filters = require "ssglib.filters"

local function render(vars)
  local html = elements.html
  return elements.concat {
    elements.raw "<!DOCTYPE html>\n",
    html.html { lang = "en",
      html.head {
        html.meta { charset = "utf-8" },
        html.title { vars.title },
      },
      html.body {
        html.main {
          html.h1 { vars.title },
          elements.raw(vars.body),
        },
      },
    },
  }
end

local s = site.Site.new(arg[2])
local v = vault.Vault.new(arg[1])

for note in v.notes:iter() do
  local doc = v:doc(note)
  doc = doc:walk {
    Para = filters.figure_filter,
    Link = filters.make_link_filter(v, note),
  }
  local vars = {
    title = paths.stem(note),
    body = pandoc.write(doc, "html5"),
  }
  s:write_data(v:url(note), pandoc.layout.render(render(vars), 72))
end

s:cleanup()
```

### Build Pipeline

Build steps:

1.  **Load the vault** – `Vault.new()` scans and indexes the vault, then
    reads each note’s `permalink` front matter.

2.  **Iterate notes** – `vault.notes` lists the vault-relative POSIX
    path of every `.md` file.

3.  **Parse and filter** – `vault:doc(path)` parses a note into a Pandoc
    document. `doc:walk(filter)` resolves wikilinks and wraps image-led
    paragraphs as figures.

4.  **Render HTML** – `pandoc.write(doc, "html5")` converts the filtered
    document to HTML. A render function and the element builder wrap it
    in a page template.

5.  **Write output** – `Site:write_data()` writes the HTML and skips
    unchanged files.

6.  **Clean up** – `Site:cleanup()` removes output files not written by
    this build.

## Vault

Obsidian vault.

### Vault.new(dir, prefix)

Scan a directory into a vault. Index file symlinks normally; warn and
skip directory symlinks.

**Parameters**

- `dir` `string` — Vault root
- `prefix` `string|nil` — URL path prefix (default “/”), must start and
  end with “/”

**Returns**

- `vault` `ssglib.Vault` — Indexed vault

### Vault:system_path(path)

Return the full filesystem path for a vault-relative POSIX path.

**Parameters**

- `path` `string` — Vault-relative POSIX path

**Returns**

- `system_path` `string` — Full filesystem path

### Vault:resolve(target, source)

Resolve a link target to a vault-relative POSIX path. Full paths work
with or without `.md`. For duplicate bare filenames, Obsidian apparently
chooses the shortest path relative to the source; that heuristic is
unimplemented, and `source` is reserved for it.

**Parameters**

- `target` `string` — Link target to resolve
- `source` `string` — Source path, reserved for bare-name resolution

**Returns**

- `path` `string|nil` — Resolved path, or nil

### Vault:url(path)

Return the URL for a vault-relative POSIX path.

**Parameters**

- `path` `string` — Vault-relative POSIX path (e.g. “articles/Hello
  World.md” or “images/photo.jpg”)

**Returns**

- `url` `string`

### Vault:doc(path)

Parse a file into a Pandoc document.

**Parameters**

- `path` `string` — Vault-relative POSIX path

**Returns**

- `pandoc.Doc` `table`

## Site

Manage a static site’s output directory.

### Site.new(dir, prefix)

Create a site.

**Parameters**

- `dir` `string` — Output root
- `prefix` `string|nil` — URL path prefix (default “/”), must start and
  end with “/”

**Returns**

- `site` `ssglib.Site` — New site

### Site:cached(key, stat, compute)

Memoize a value against a source file’s stat. The cache persists across
builds and recomputes only when size or mtime changes. Passing the stat
lets one source snapshot drive other freshness checks, such as
`write_file`. Nil results are also cached.

**Parameters**

- `key` `string` — Stable key, such as a vault-relative path
- `stat` `Stat` — Current stat of the source
- `compute` `fun():<T>` — Function to compute the value on a cache miss

**Returns**

- `value` `<T>` — Cached or computed value

### Site:prepare(url)

Prepare the output file for a URL and create its directories. Reject
traversal outside the root and conflicting URLs. File targets are
case-insensitive to match common filesystems such as APFS and NTFS.
Return the output file’s system path.

**Parameters**

- `url` `string` — Absolute URL path

**Returns**

- `path` `string` — File system path

### Site:write_data(url, data)

Write data to a URL.

**Parameters**

- `url` `string` — Absolute URL path
- `data` `string` — Content to write to file

### Site:write_css(url)

Join and minify CSS sources, then write them to a URL. Return the target
with a content-derived `?v=<hash>` query.

**Parameters**

- `url` `string` — Absolute URL path
- `...` `string` — CSS sources, joined in order with newlines

**Returns**

- `url` `string` — Target with a content-hash query

### Site:write_js(url)

Join and minify JavaScript sources, then write them to a URL. Return the
target with a content-derived `?v=<hash>` query.

**Parameters**

- `url` `string` — Absolute URL path
- `...` `string` — JavaScript sources, joined in order with newlines

**Returns**

- `url` `string` — Target with a content-hash query

### Site:write_file(url, path, stat)

Copy a file to a URL unless the target is newer.

**Parameters**

- `url` `string` — Absolute URL path
- `path` `string` — File path
- `stat` `Stat|nil` — Precomputed source stat (read from disk if
  omitted)

**Returns**

- `updated` `boolean` — Whether the file was copied

### Site:write_dir(url, root)

Copy a directory to a URL, skipping dot-prefixed paths. Copy file
symlinks; warn and skip directory symlinks.

**Parameters**

- `url` `string` — Absolute URL path ending with “/”
- `root` `string` — Directory path

### Site:cleanup()

Remove unused output files. Remove symlinks as leaves without following
them.

## Elements

Programmatic HTML and XML generation.

### elements.render(value)

Render a value as an HTML-escaped layout.Doc.

**Parameters**

- `value` `any` — Value to render

**Returns**

- `layout.Doc` `table`

### elements.concat(t, sep)

Render and join values as a layout.Doc.

**Parameters**

- `t` `table` — Values to render and join
- `sep` `any` — Separator between values

### elements.raw

Return raw, unescaped layout output.

### elements.html

Lazily created HTML element builders (e.g. `html.div { ... }`).

### elements.xml

Lazily created XML element builders (e.g. `xml.item { ... }`).

## Filters

Pandoc filters for building a static site from an Obsidian vault.

### filters.figure_filter(para)

Convert an image-led paragraph to a single-image gallery `Figure`.

An image-led paragraph:

``` text
![](https://example.com/image.png) caption
```

becomes a `gallery single` Figure containing a lightbox tile and the
paragraph’s remaining text as its caption. An image alone has no
`<figcaption>`; other paragraphs remain unchanged. The `single` layout
prevents the tile from exceeding the gallery’s width in height.

**Parameters**

- `para` `pandoc.Para`

**Returns**

- `converted` `pandoc.Figure|nil` — Figure, or nil if not image-led

### filters.gallery_filter(div)

Convert a fenced-div image gallery to a `Figure`.

A fenced div with a gallery-mode class:

``` text
::: collage-landscape
![](https://example.com/one.jpg) caption

![](https://example.com/two.jpg)

Text about the gallery.
:::
```

becomes a `gallery` Figure that retains the div’s classes. Each
image-led paragraph becomes a lightbox tile; other blocks form one
`<figcaption>` after the tiles. Use separate galleries for content
between image rows.

For a top-down walk, return `figure, false` to prevent paragraph filters
from reprocessing gallery images.

**Parameters**

- `div` `pandoc.Div`

**Returns**

- `figure` `pandoc.Figure|nil` — Gallery, or nil
- `halt` `boolean?` — False after conversion to stop descent

### filters.make_image_filter(vault, site, source)

Create a filter that copies vault images to the site. Leave `.base`
query embeds unchanged.

**Parameters**

- `vault` `ssglib.Vault` — Obsidian vault.
- `site` `ssglib.Site` — Manage a static site’s output directory.
- `source` `string` — Source path for resolving links

**Returns**

- `filter` `fun(img: pandoc.Image):pandoc.Image|nil` — Image filter

### filters.make_link_filter(vault, source)

Create a filter that resolves vault links.

**Parameters**

- `vault` `ssglib.Vault` — Obsidian vault.
- `source` `string` — Source path for resolving links

**Returns**

- `filter` `fun(link: pandoc.Link):pandoc.Link|nil` — Link filter

### filters.make_codeblock_filter(env)

Create a filter that executes Lua code blocks.

**Parameters**

- `env` `table?` — Execution environment; defaults to `_G`
- `...` `any` — Arguments passed to executed code

**Returns**

- `filter` `fun(code: pandoc.CodeBlock):pandoc.Block|pandoc.CodeBlock|nil` — Code-block
  filter

## Paths

Path and filesystem utilities.

### paths.posix_path(s)

Convert system paths to POSIX paths.

### paths.system_path(s)

Convert POSIX paths to system-native paths.

### paths.stem(path)

Return a POSIX path’s filename without its directory or extension.

**Parameters**

- `path` `string` — POSIX file path

**Returns**

- `stem` `string`

### paths.is_local_path(url)

Check whether a URL is a vault path. URLs with a scheme or host are
external.

**Parameters**

- `url` `string` — URL to check

**Returns**

- `...` `boolean`

### paths.file_exists(path)

Check whether a file is readable.

**Parameters**

- `path` `string` — File path

**Returns**

- `...` `boolean`

### paths.is_symlink(path)

Check whether a path is a symbolic link.

**Parameters**

- `path` `string` — File path

**Returns**

- `...` `boolean`

### paths.stat(path)

Snapshot a file’s size and modification time.

**Parameters**

- `path` `string` — File path

**Returns**

- `...` `Stat`

### paths.walk_tree(root, fn, include_hidden)

Walk a directory tree, calling a function for each leaf. Symbolic links
are leaves and are never followed. Unless `include_hidden` is true,
dot-prefixed files and directories are skipped.

**Parameters**

- `root` `string` — Root directory
- `fn` `fun(path: string, is_symlink: boolean):nil` — Called for each
  file or symbolic link
- `include_hidden` `boolean|nil` — Include dot-prefixed paths

### paths.remove_empty_dirs(root)

Remove empty directories beneath `root`, deepest first. Never remove
`root` itself.

**Parameters**

- `root` `string` — Root directory

## RSS

Generate RSS 2.0 feeds.

### rss.head_link(url, channel)

Return an RSS-discovery `<link>` for an HTML `<head>`.

**Parameters**

- `url` `string` — Feed URL (e.g. “/feed.xml”)
- `channel` `table` — Channel metadata with `title`

**Returns**

- `layout.Doc` `table`

### rss.write_rss(site, vault, url, channel, items)

Write an RSS 2.0 feed to the site.

`items` should come from `query_base()` with these base fields:

- path (string): vault-relative note path (e.g. “articles/My Post.md”)
- “file name” (string): note title (built-in base attribute)
- date (string): ISO 8601 publication date (YYYY-MM-DD)
- description (string): plain-text summary

**Parameters**

- `site` `ssglib.Site` — Destination site
- `vault` `ssglib.Vault` — Vault for resolving note URLs
- `url` `string` — Feed URL (e.g. “/feed.xml”)
- `channel` `table` — Channel title, link, and description
- `items` `pandoc.List` — `query_base()` results with the fields above

## Gallery

Fenced-div gallery assets.

### gallery.css()

Return the gallery CSS.

**Returns**

- `css` `string`

### gallery.js()

Return the gallery JavaScript for final-row sizing and the lightbox.

**Returns**

- `js` `string`
