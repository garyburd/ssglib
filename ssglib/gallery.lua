--- Fenced-div gallery assets. CSS justifies rows; JavaScript refines the final
--- row and adds a lightbox.
--- Dependencies: Pandoc

local pandoc = require "pandoc"

local dir = debug.getinfo(1, "S").source:match("^@(.*/)")

--- Fenced-div gallery assets.
---@class ssglib.gallery
local M = {}

--- Return the gallery CSS.
---@return string css
function M.css()
  return pandoc.system.read_file(dir .. "gallery.css")
end

--- Return the gallery JavaScript for final-row sizing and the lightbox.
---@return string js
function M.js()
  return pandoc.system.read_file(dir .. "gallery.js")
end

return M
