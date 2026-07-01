--- Programmatic HTML and XML generation.
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

-- Attributes are double-quoted, so apostrophes need no escaping.
local substitutions = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["\r"] = " ",
  ["\n"] = " ",
}

--- Programmatic HTML and XML generation.
---@class ssglib.elements
local M = {}

--- Render a value as an HTML-escaped layout.Doc.
---
---@param value any Value to render
---   - false: empty doc
---   - layout.Doc: unchanged
---   - other: stringified and HTML-escaped (`&`, `<`, `>`)
---
---@return table layout.Doc
function M.render(value)
  if value == false then
    return layout_empty
  end
  if pdtype(value) == "Doc" then
    return value
  end
  return layout_literal(stringify(value):gsub("[&><]", substitutions))
end

--- Render and join values as a layout.Doc.
---
---@param t table Values to render and join
---@param sep any|nil Separator between values
function M.concat(t, sep)
  local result = {}
  for i, v in ipairs(t) do
    result[i] = M.render(v)
  end
  return layout_concat(result, sep and M.render(sep) or nil)
end

--- Create an HTML or XML element renderer.
--- String keys are attributes (single "_" → "-", double "__" → "_"; true
--- emits the bare name and false omits it); integer keys are content.
---@param name string Tag name (e.g., "div", "img", "br")
---@param opts table|nil Options:
---   - break_before/break_after (boolean): add a newline before/after the tag.
---   - type: "void" for content-less HTML elements (<br>, <img>), "xml" to
---     self-close when empty (<tag />), or nil for standard HTML elements.
---@return function renderer Accepts `elem` and returns a layout.Doc
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
      -- Omit false-valued attributes.
      if type(key) == "string" and value then
        table.insert(keys, key)
      end
    end
    -- Stabilize output.
    table.sort(keys)

    for _, key in ipairs(keys) do
      table.insert(result, layout_space)
      local k = key:gsub("__", "\0"):gsub("_", "-"):gsub("\0", "_")
      table.insert(result, k)
      local value = elem[key]
      if value ~= true then
        table.insert(result, "=")
        -- Escape attribute values (`&`, `<`, `>`, `"`, CR, LF).
        value = tostring(value):gsub('[&<>"\r\n]', substitutions)
        table.insert(result, layout_double_quotes(value))
      end
    end

    if tag_type == "void" then
      -- Void elements have no content or closing tag.
      table.insert(result, close)
    elseif tag_type == "xml" and not elem[1] then
      -- Self-close empty XML elements.
      table.insert(result, "/>")
    else
      -- Standard element with content.
      table.insert(result, ">")
      table.insert(result, M.concat(elem))
      table.insert(result, close)
    end
    return layout_concat(result)
  end
end

-- HTML5 void and line-break settings. Block elements break before and after.
local block_opt = { break_before = true, break_after = true }
local void_opt = { type = "void" }
local void_block_opt = { type = "void", break_before = true, break_after = true }

local html_options = {
  -- Void elements
  area = void_opt,
  base = void_opt,
  br = { type = "void", break_after = true },
  col = void_opt,
  embed = void_opt,
  hr = void_block_opt,
  img = void_opt,
  input = void_opt,
  link = void_block_opt,
  meta = void_block_opt,
  source = void_opt,
  track = void_opt,
  wbr = void_opt,

  -- Document structure
  html = block_opt,
  head = block_opt,
  body = block_opt,

  -- Sectioning
  article = block_opt,
  aside = block_opt,
  footer = block_opt,
  header = block_opt,
  main = block_opt,
  nav = block_opt,
  section = block_opt,

  -- Headings
  h1 = block_opt, h2 = block_opt, h3 = block_opt, h4 = block_opt, h5 = block_opt, h6 = block_opt,

  -- Block content
  address = block_opt,
  blockquote = block_opt,
  details = block_opt,
  dialog = block_opt,
  div = block_opt,
  dl = block_opt,
  dt = block_opt,
  dd = block_opt,
  fieldset = block_opt,
  figcaption = block_opt,
  figure = block_opt,
  form = block_opt,
  legend = block_opt,
  li = block_opt,
  ol = block_opt,
  p = block_opt,
  pre = block_opt,
  summary = block_opt,
  table = block_opt,
  caption = block_opt,
  thead = block_opt,
  tbody = block_opt,
  tfoot = block_opt,
  tr = block_opt,
  ul = block_opt,

  -- Other block-level
  noscript = block_opt,
  script = block_opt,
  style = block_opt,
  template = block_opt,
  title = block_opt,
}

-- Lazily create HTML element functions.
local function html_index(elements, key)
  local value = element_function(key, html_options[key])
  elements[key] = value
  return value
end

local xml_options = {
  type = "xml",
}

-- Lazily create XML element functions.
local function xml_index(elements, key)
  local value = element_function(key, xml_options)
  elements[key] = value
  return value
end

--- Return raw, unescaped layout output.
---@type fun(s: string): table
M.raw = layout_literal

--- Lazily created HTML element builders (e.g. `html.div { ... }`).
M.html = setmetatable({}, { __index = html_index })

--- Lazily created XML element builders (e.g. `xml.item { ... }`).
M.xml = setmetatable({}, { __index = xml_index })

return M
