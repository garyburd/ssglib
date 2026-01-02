--- @meta

--- Pandoc Lua type definitions for LuaLS
--- Based on Pandoc Lua Filters documentation

--- @class pandoc.List
--- @field [integer] any
local List = {}

--- Create a shallow copy of the list
--- @return pandoc.List
function List:clone() end

--- Extend the list by appending all items from another list
--- @param list pandoc.List List to append
--- @return pandoc.List self The extended list
function List:extend(list) end

--- Find the first occurrence of an item in the list
--- @param needle any Item to search for
--- @param init integer? Starting index (default: 1)
--- @return integer|nil index Index of the item, or nil if not found
function List:find(needle, init) end

--- Find the first item for which the predicate returns true
--- @param pred fun(item: any): boolean Predicate function
--- @param init integer? Starting index (default: 1)
--- @return any|nil item The found item, or nil
function List:find_if(pred, init) end

--- Filter the list, keeping only items for which the predicate returns true
--- @param pred fun(item: any): boolean Predicate function
--- @return pandoc.List filtered Filtered list
function List:filter(pred) end

--- Test whether all items in the list satisfy the predicate
--- @param pred fun(item: any): boolean Predicate function
--- @return boolean
function List:all(pred) end

--- Test whether any item in the list satisfies the predicate
--- @param pred fun(item: any): boolean Predicate function
--- @return boolean
function List:any(pred) end

--- Apply a function to all items, collecting the results
--- @param fn fun(item: any): any Function to apply
--- @return pandoc.List mapped Mapped list
function List:map(fn) end

--- Insert an item at the specified position
--- @param pos integer Position to insert at (1-based)
--- @param value any Item to insert
function List:insert(pos, value) end

--- Remove and return the item at the specified position
--- @param pos integer? Position to remove from (default: end of list)
--- @return any removed The removed item
function List:remove(pos) end

--- Sort the list in place
--- @param comp fun(a: any, b: any): boolean? Optional comparison function
function List:sort(comp) end

--- Check if the list includes a specific item
--- @param needle any Item to search for
--- @param init integer? Starting index (default: 1)
--- @return boolean
function List:includes(needle, init) end

--- Return a new list with all items in reverse order
--- @return pandoc.List reversed Reversed list
function List:reverse() end

--- Apply a function to each item (for side effects)
--- @param fn fun(item: any) Function to apply
function List:foreach(fn) end

--- Return an iterator over list items
--- @return fun(): any iterator Iterator function
function List:iter() end

--- @class pandoc.Attr
--- @field identifier string Element identifier
--- @field classes pandoc.List List of class names (strings)
--- @field attributes pandoc.Attributes Key-value pairs of attributes

--- @class pandoc.Attributes
--- @field [string] string String-indexed key-value pairs

--- @class pandoc.Inlines: pandoc.List

--- @class pandoc.Blocks: pandoc.List

--- @class pandoc.Element
--- @field tag string The type tag (e.g., "Para", "Header", "Div")
--- @field t string Alias for tag
--- @field identifier string Alias for attr.identifier
--- @field classes pandoc.List Alias for attr.classes
--- @field attributes pandoc.Attributes Alias for attr.attributes

--- @class pandoc.Block: pandoc.Element
--- @field walk fun(self: pandoc.Block, filter: table): pandoc.Block Apply a filter to the block's contents

--- @class pandoc.Para: pandoc.Block
--- @field content pandoc.Inlines Inline content

--- @class pandoc.Plain: pandoc.Block
--- @field content pandoc.Inlines Inline content

--- @class pandoc.CodeBlock: pandoc.Block
--- @field text string Code content

--- @class pandoc.RawBlock: pandoc.Block
--- @field format string Format of content (e.g., "html", "latex")
--- @field text string Raw content

--- @class pandoc.BlockQuote: pandoc.Block
--- @field content pandoc.Blocks Block content

--- @class pandoc.BulletList: pandoc.Block
--- @field content pandoc.List List of items (each item is a pandoc.Blocks)

--- @class pandoc.Div: pandoc.Block
--- @field content pandoc.Blocks Block content

--- @class pandoc.Figure: pandoc.Block
--- @field content pandoc.Blocks Block content
--- @field caption pandoc.Caption Figure caption

--- @class pandoc.Caption
--- @field long pandoc.Blocks Full caption
--- @field short pandoc.Inlines Short summary caption

--- @class pandoc.Inline: pandoc.Element
--- @field walk fun(self: pandoc.Inline, filter: table): pandoc.Inline Apply a filter to the inline's contents

--- @class pandoc.Str: pandoc.Inline
--- @field text string Text content

--- @class pandoc.Space: pandoc.Inline

--- @class pandoc.SoftBreak: pandoc.Inline

--- @class pandoc.LineBreak: pandoc.Inline

--- @class pandoc.Image: pandoc.Inline
--- @field caption pandoc.Inlines Alt text / image description
--- @field src string Path to image file or URL
--- @field title string Image title

--- @class pandoc.Link: pandoc.Inline
--- @field content pandoc.Inlines Link text
--- @field target string URL or link target
--- @field title string Link title (tooltip text)
