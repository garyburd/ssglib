---
permalink: getting-started/
---

# Getting Started

This guide walks through building a static site from an Obsidian vault using ssglib and Pandoc.

## Prerequisites

- [Pandoc](https://pandoc.org/installing.html) with Lua support (`pandoc-lua`)
- An Obsidian vault with markdown files

## Project Structure

A typical ssglib project looks like this:

```
my-site/
├── main.lua        # Site builder script
├── vault/          # Obsidian vault (markdown source)
│   ├── index.md
│   └── about.md
├── static/         # Static files copied to output
└── docs/           # Generated output
```

## Minimal main.lua

Here is a minimal site builder:

```lua
local pandoc = require "pandoc"
local elements = require "ssglib.elements"
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
local cache_file = s:prepare("/.cache.json")
local v = vault.Vault.load(arg[1], cache_file)

local filter = {
  BlockQuote = filters.callout_filter,
  Link = filters.make_link_filter(v),
}

for f in v:notes():iter() do
  local doc = f:doc():walk(filter)
  local vars = {
    title = f:title(),
    body = pandoc.write(doc, "html5"),
  }
  s:write_data(f:url(), pandoc.layout.render(render(vars), 72))
end

s:cleanup()
```

## Build Pipeline

The build process follows these steps:

1. **Load the vault** – `Vault.load()` scans the vault directory, reads front matter from each note, and caches the results.

2. **Iterate notes** – `Vault:notes()` returns all markdown files in the vault.

3. **Parse and filter** – `File:doc()` parses a note into a Pandoc document. Calling `doc:walk(filter)` applies filters that resolve wikilinks, process callouts, and evaluate code blocks.

4. **Render HTML** – `pandoc.write(doc, "html5")` converts the filtered document to HTML. A render function wraps the content in a full page template using the [[Elements]] module.

5. **Write output** – `Site:write_data()` writes the rendered HTML to the output directory. Unchanged files are skipped for fast incremental builds.

6. **Clean up** – `Site:cleanup()` removes any files in the output directory that were not written during this build.

## Running the Build

```bash
pandoc-lua main.lua vault docs
```

To serve locally for development:

```bash
python3 -m http.server --directory docs
```

## Front Matter

Notes can include YAML front matter to control output:

```yaml
---
permalink: about/       # Custom URL (default: derived from filename)
date: 2025-01-15        # Publication date
hide: true              # Exclude from contents listings
tags:
  - "#topic"
---
```

If `permalink` is omitted, the URL is derived from the file path with spaces replaced by hyphens and the `.md` extension replaced by `/`.
