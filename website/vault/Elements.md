---
permalink: elements/
---

# Elements

The `ssglib.elements` module generates HTML and XML using Pandoc's layout engine. Elements are created by calling functions on the `html` or `xml` tables.

```lua
local elements = require "ssglib.elements"
local html = elements.html
```

## Element Functions

Access any HTML element as a function on `html`. The function takes a table with attributes (string keys) and content (integer keys).

```lua
html.div { class = "container",
  html.h1 { "Hello" },
  html.p { "World" },
}
```

XML elements work the same way via `elements.xml`. Empty XML elements render as self-closing tags.

## Attributes

String keys in the table become element attributes.

- `true` renders the attribute name only: `html.input { disabled = true }` → `<input disabled>`
- `false` omits the attribute entirely
- Single `_` in key names becomes `-`: `data_id` → `data-id`
- Double `__` becomes `_`: `my__var` → `my_var`

```lua
html.meta { http_equiv = "X-UA-Compatible", content = "IE=edge" }
-- <meta content="IE=edge" http-equiv="X-UA-Compatible">
```

## raw(text)

Insert raw HTML without escaping. Returns a layout Doc.

```lua
elements.raw("<!DOCTYPE html>\n")
```

## concat(t, sep)

Concatenate a sequence of values with an optional separator. Each value is rendered and HTML-escaped (unless it is already a layout Doc).

```lua
elements.concat({ "one", "two", "three" }, ", ")
-- "one, two, three"
```

## render(value)

Render a single value to a layout Doc with HTML escaping. `false` returns an empty Doc, layout Docs pass through unchanged, and other values are stringified and escaped.

