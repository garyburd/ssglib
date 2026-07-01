---@meta

--- Pandoc types for LuaLS
--- From the Pandoc Lua Filters documentation

---@alias pandoc.ListPred fun(item: any): boolean
---@alias pandoc.ListMapFn fun(item: any): any
---@alias pandoc.ListCmp fun(a: any, b: any): boolean

---@class pandoc.List
---@field [integer] any
---@field clone fun(self: pandoc.List): pandoc.List Shallow copy.
---@field extend fun(self: pandoc.List, list: pandoc.List): pandoc.List Append all items from another list.
---@field find fun(self: pandoc.List, needle: any, init: integer|nil): integer|nil Index of the first occurrence, or nil.
---@field find_if fun(self: pandoc.List, pred: pandoc.ListPred, init: integer|nil): any First item satisfying pred, or nil.
---@field filter fun(self: pandoc.List, pred: pandoc.ListPred): pandoc.List Items satisfying pred.
---@field all fun(self: pandoc.List, pred: pandoc.ListPred): boolean True if every item satisfies pred.
---@field any fun(self: pandoc.List, pred: pandoc.ListPred): boolean True if any item satisfies pred.
---@field map fun(self: pandoc.List, fn: pandoc.ListMapFn): pandoc.List Apply fn to every item; collect results.
---@field insert fun(self: pandoc.List, pos: integer, value: any) Insert value at 1-based position.
---@field remove fun(self: pandoc.List, pos: integer|nil): any Remove and return item at pos (default: last).
---@field sort fun(self: pandoc.List, comp: pandoc.ListCmp|nil) Sort in place.
---@field includes fun(self: pandoc.List, needle: any, init: integer|nil): boolean True if list contains needle.
---@field reverse fun(self: pandoc.List): pandoc.List New list in reverse order.
---@field iter fun(self: pandoc.List): fun(): any Iterator over items.

---@class pandoc.Attr
---@field identifier string Element identifier
---@field classes pandoc.List List of class names (strings)
---@field attributes pandoc.Attributes Key-value pairs of attributes

---@class pandoc.Attributes
---@field [string] string String-indexed key-value pairs

---@class pandoc.Inlines: pandoc.List

---@class pandoc.Blocks: pandoc.List

---@class pandoc.Element
---@field tag string Type tag (e.g., "Para", "Header", "Div")
---@field t string Alias for tag
---@field identifier string Alias for attr.identifier
---@field classes pandoc.List Alias for attr.classes
---@field attributes pandoc.Attributes Alias for attr.attributes

---@class pandoc.Block: pandoc.Element
---@field walk fun(self: pandoc.Block, filter: table): pandoc.Block Apply a filter to the block's contents

---@class pandoc.Para: pandoc.Block
---@field content pandoc.Inlines Inline content

---@class pandoc.Plain: pandoc.Block
---@field content pandoc.Inlines Inline content

---@class pandoc.CodeBlock: pandoc.Block
---@field text string Code content

---@class pandoc.RawBlock: pandoc.Block
---@field format string Format of content (e.g., "html", "latex")
---@field text string Raw content

---@class pandoc.BlockQuote: pandoc.Block
---@field content pandoc.Blocks Block content

---@class pandoc.BulletList: pandoc.Block
---@field content pandoc.List List of items (each item is a pandoc.Blocks)

---@class pandoc.Div: pandoc.Block
---@field content pandoc.Blocks Block content

---@class pandoc.Figure: pandoc.Block
---@field content pandoc.Blocks Block content
---@field caption pandoc.Caption Figure caption

---@class pandoc.Caption
---@field long pandoc.Blocks Full caption
---@field short pandoc.Inlines Short summary caption

---@class pandoc.Inline: pandoc.Element
---@field walk fun(self: pandoc.Inline, filter: table): pandoc.Inline Apply a filter to the inline's contents

---@class pandoc.Str: pandoc.Inline
---@field text string Text content

---@class pandoc.Space: pandoc.Inline

---@class pandoc.SoftBreak: pandoc.Inline

---@class pandoc.LineBreak: pandoc.Inline

---@class pandoc.Image: pandoc.Inline
---@field caption pandoc.Inlines Alt text / image description
---@field src string Path to image file or URL
---@field title string Image title

---@class pandoc.Link: pandoc.Inline
---@field content pandoc.Inlines Link text
---@field target string URL or link target
---@field title string Link title (tooltip text)
