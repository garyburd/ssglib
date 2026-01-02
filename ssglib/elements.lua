--- Library for programmatically generating HTML and XML.
--- Dependencies: Pandoc

local pandoc = require "pandoc"

local pdtype = pandoc.utils.type
local stringify = pandoc.utils.stringify

local layout_space = pandoc.layout.space
local layout_empty = pandoc.layout.empty
local layout_concat = pandoc.layout.concat
local layout_literal = pandoc.layout.literal
local layout_cr = pandoc.layout.cr
local layout_double_quotes = pandoc.layout.double_quotes

local substitutions = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["\r"] = " ",
  ["\n"] = " ",
}

--- Renders a value to a layout.Doc object with HTML escaping.
---
--- @param value any The value to render.
---   - false: returns empty doc
---   - layout.Doc: passed through unchanged
---   - other: converted to string and HTML-escaped (&, <, > characters)
---
---@return table layout.Doc
local function render(value)
  if value == false then
    return layout_empty
  end
  if pdtype(value) == "Doc" then
    -- Nothing to do.
    return value
  end
  return layout_literal(stringify(value):gsub("[&><]", substitutions))
end

--- Renders a sequence of values to a layout.Doc with optional separator.
---
--- @param t table Sequence of values to render and concatenate.
--- @param sep any|nil Optional separator inserted between elements.
local function concat(t, sep)
  local result = {}
  for i, v in ipairs(t) do
    result[i] = render(v)
  end
  return layout_concat(result, sep and render(sep) or nil)
end

--- Creates a function that renders an HTML or XML element to a layout.Doc.
---
-- This factory function generates element renderers that convert Lua table
--- representations into properly formatted HTML/XML elements with attributes and content.
---
--- @param name string The tag name (e.g., "div", "img", "br").
---
--- @param opts table|nil Optional configuration for element rendering:
---   - break_before (boolean): If true, inserts a newline before the opening tag.
---   - break_after (boolean): If true, inserts a newline after the closing tag.
---   - type (string|nil): Specifies the tag type:
---       * "void": HTML void elements (e.g., <br>, <img>) - no content, no closing tag.
---       * "xml": XML-style elements - renders as self-closing <tag /> when empty.
---       * nil: Standard HTML elements - always includes a closing tag.
---
--- @return function A generator function that accepts a table `elem` and returns a layout.Doc.
---
---   The returned function processes `elem` as follows:
---   - **Attributes** (string keys):
---       * Key transformation: single "_" becomes "-", double "__" becomes "_"
---         (e.g., `data_id` → `data-id`, `my__var` → `my_var`)
---       * Boolean true: renders attribute name only (e.g., `disabled = true` → `disabled`)
---       * Boolean false: attribute is omitted entirely
---       * Other values: rendered as `key="value"` with proper escaping
---   - **Content** (integer keys):
---       * Sequential integer keys (1, 2, 3, ...) specify child nodes/content
---       * Ignored for void elements
---       * Empty content triggers self-closing syntax for XML elements
---
--- @usage
---   local div = element_function("div", {break_after = true})
---   div({class = "container", "Hello ", "World"})
---   -- Produces: <div class="container">Hello World</div>\n
---
---   local img = element_function("img", {type = "void"})
---   img({src = "pic.jpg", alt = "Photo"})
---   -- Produces: <img alt="Photo" src="pic.jpg">
local function element_function(name, opts)
  opts = opts or {}
  local open = string.format("<%s", name)
  local close = (opts.type ~= "void") and string.format("</%s>", name) or ">"

  if opts.break_before then
    open = layout_concat { layout_cr, open }
  end
  if opts.break_after then
    close = layout_concat { close, layout_cr }
  end

  local tag_type = opts.type

  return function(elem)
    local result = { open }

    local keys = {}
    for key, value in pairs(elem) do
      -- Ignore attributes with false value.
      if type(key) == "string" and value then
        table.insert(keys, key)
      end
    end
    -- Sort for stable output.
    table.sort(keys)

    for _, key in ipairs(keys) do
      table.insert(result, layout_space)
      local k = key:gsub("__", "\0"):gsub("_", "-"):gsub("\0", "_")
      table.insert(result, k)
      local value = elem[key]
      if value ~= true then
        table.insert(result, "=")
        -- Escape attribute values (&, ", \r, \n become &amp;, &quot;, space, space)
        value = tostring(value):gsub('[&"\r\n]', substitutions)
        table.insert(result, layout_double_quotes(value))
      end
    end

    if tag_type == "void" then
      -- Void elements (e.g., <br>, <img>) do not have closing tags or content
      table.insert(result, close)
    elseif tag_type == "xml" and not elem[1] then
      -- Self-closing XML elements if no content provided
      table.insert(result, "/>")
    else
      -- Standard elements with content
      table.insert(result, ">") -- Close the opening tag
      table.insert(result, concat(elem))
      table.insert(result, close)
    end
    return layout_concat(result)
  end
end

-- Configuration for standard HTML5 elements specifying void elements and line breaks
local html_options = {
  area = { type = "void" },
  article = { break_before = true, break_after = true },
  base = { type = "void" },
  body = { break_before = true, break_after = true },
  br = { type = "void", break_after = true },
  col = { type = "void" },
  div = { break_before = true, break_after = true },
  embed = { type = "void" },
  figure = { break_before = true, break_after = true },
  footer = { break_before = true, break_after = true },
  h1 = { break_before = true, break_after = true },
  h2 = { break_before = true, break_after = true },
  h3 = { break_before = true, break_after = true },
  h4 = { break_before = true, break_after = true },
  h5 = { break_before = true, break_after = true },
  h6 = { break_before = true, break_after = true },
  head = { break_before = true, break_after = true },
  header = { break_before = true, break_after = true },
  hr = { type = "void", break_before = true, break_after = true },
  html = { break_before = true, break_after = true },
  img = { type = "void" },
  input = { type = "void" },
  li = { break_before = true, break_after = true },
  link = { type = "void", break_before = true, break_after = true },
  main = { break_before = true, break_after = true },
  meta = { type = "void", break_before = true, break_after = true },
  ol = { break_before = true, break_after = true },
  p = { break_before = true, break_after = true },
  source = { type = "void" },
  title = { break_before = true, break_after = true },
  track = { type = "void" },
  ul = { break_before = true, break_after = true },
  wbr = { type = "void" },
}

-- Metatable indexer that lazily creates HTML element functions on access.
local function html_index(elements, key)
  local value = element_function(key, html_options[key])
  elements[key] = value
  return value
end

local xml_options = {
  type = "xml",
}

-- Metatable indexer that lazily creates XML element functions on access.
local function xml_index(elements, key)
  local value = element_function(key, xml_options)
  elements[key] = value
  return value
end

return {
  raw = layout_literal,
  concat = concat,
  render = render,
  html = setmetatable({}, { __index = html_index }),
  xml = setmetatable({}, { __index = xml_index }),
}
