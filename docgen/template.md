# ssglib

Lua library for building static websites from [Obsidian](https://obsidian.md) vaults with [Pandoc](https://pandoc.org).

Features:

- Read Obsidian vaults with front matter and wikilinks
- Resolve wikilinks and wrap image-led paragraphs as figures
- Build HTML and XML programmatically
- Update output directories incrementally

`docgen/main.lua` generates this file. Edit `docgen/template.md` or the source doc comments, not this file.

## Getting Started

Build a static site from an Obsidian vault with ssglib and Pandoc.

### Prerequisites

- [Pandoc](https://pandoc.org/installing.html) with Lua support (`pandoc-lua`)
- An Obsidian vault with markdown files

### Minimal main.lua

Minimal site builder:

```lua
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

1. **Load the vault** -- `Vault.new()` scans and indexes the vault, then reads each note's `permalink` front matter.

2. **Iterate notes** -- `vault.notes` lists the vault-relative POSIX path of every `.md` file.

3. **Parse and filter** -- `vault:doc(path)` parses a note into a Pandoc document. `doc:walk(filter)` resolves wikilinks and wraps image-led paragraphs as figures.

4. **Render HTML** -- `pandoc.write(doc, "html5")` converts the filtered document to HTML. A render function and the element builder wrap it in a page template.

5. **Write output** -- `Site:write_data()` writes the HTML and skips unchanged files.

6. **Clean up** -- `Site:cleanup()` removes output files not written by this build.

```eval
api.reference()
```
