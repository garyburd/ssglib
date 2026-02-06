---
permalink: filters/
---

# Filters

The `ssglib.filters` module provides Pandoc filter functions for processing Obsidian vault content. Filters are passed to `doc:walk()` to transform a Pandoc document.

```lua
local filters = require "ssglib.filters"
```

## callout_filter

A filter function for `BlockQuote` elements. Converts Obsidian callout syntax into Pandoc `Div` or `Figure` elements.

Standard callouts become a `Div` with classes `callout` and `callout-<marker>`:

```markdown
> [!warning] This is important.
```

Figure callouts become a `Figure` element with caption:

```markdown
> [!figure] ![[photo.jpg]]
> A photo caption.
```

Usage:

```lua
local filter = { BlockQuote = filters.callout_filter }
doc = doc:walk(filter)
```

## make_link_filter(vault)

Create a `Link` filter that resolves vault wikilinks to URLs. Links to files not found in the vault are left unchanged.

```lua
local filter = { Link = filters.make_link_filter(vault) }
doc = doc:walk(filter)
```

Given a vault note `Hello World.md` with `permalink: hello/`, a wikilink `[[Hello World]]` becomes a link to `/hello/`.

## make_image_filter(vault, site)

Create an `Image` filter that copies images from the vault to the site and generates responsive `srcset` attributes. The filter creates multiple resized versions of each image.

```lua
local filter = { Image = filters.make_image_filter(vault, site) }
doc = doc:walk(filter)
```

This filter requires GraphicsMagick (`gm convert`) for image resizing.

## make_codeblock_filter(env, ...)

Create a `CodeBlock` filter that executes code blocks with the `eval` class. The code is run in the provided environment table and the return value replaces the code block in the document.

```lua
local filter = {
  CodeBlock = filters.make_codeblock_filter(overlay(_G, {
    contents = function() return build_contents_list() end,
  })),
}
doc = doc:walk(filter)
```

In a markdown file, an evaluated code block looks like this:

````markdown
```eval
contents()
```
````

The expression is evaluated and its return value (typically a Pandoc AST element) replaces the code block. If evaluation fails, the error message is shown in a code block.
