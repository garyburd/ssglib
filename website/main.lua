local pandoc = require "pandoc"
local elements = require "ssglib.elements"
local vault = require "ssglib.vault"
local site = require "ssglib.site"
local filters = require "ssglib.filters"

local base = "/ssglib/"

local function overlay(a, b)
  return setmetatable(b, { __index = a })
end

local css = [[
body {
    max-width: 650px;
    margin: 40px auto;
    padding: 0 10px;
    font: 18px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
    color:#444
}

h1, h2, h3 { line-height:1.2 }

@media (prefers-color-scheme: dark) {
    body { color: #c9d1d9; background:#0d1117 }
    a:link { color:#58a6ff }
    a:visited { color: #8e96f0 }
}
]]

local function render(vars)
  local html = elements.html

  local main = html.article { elements.raw(vars.body) }

  return elements.concat {
    elements.raw "<!DOCTYPE html>\n",
    html.html {
      lang = "en",
      html.head {
        html.meta { charset = "utf-8" },
        html.meta { name = "viewport", content = "width=device-width, initial-scale=1.0" },
        html.style { elements.raw(css) },
        html.title { "ssglib", vars.url ~= base and elements.concat { " – ", vars.title } },
      },
      html.body {
        html.header {
          html.nav {
            class = "top",
            html.ul {
              html.li { vars.url == base and "ssglib" or html.a { href = base, title = "Home", "ssglib" } },
            },
          },
        },
        html.main { main },
      },
    },
  }
end

local Builder = {}
Builder.__index = Builder

function Builder.new(vault_path, site_path)
  local s = site.Site.new(site_path, base)
  local cache_path = s:prepare(base .. ".cache.json")
  local v = vault.Vault.load(vault_path, cache_path, base)
  local self = setmetatable({ vault = v, site = s }, Builder)
  self.filter = {
    BlockQuote = filters.callout_filter,
    Link = filters.make_link_filter(self.vault),
  }
  return self
end

function Builder:make_page(vars, f)
  local doc = f:doc()
  doc = doc:walk(self.filter)
  vars = overlay(vars, {
    url = f:url(),
    title = f:title(),
    body = pandoc.write(doc, "html5"),
    article = true,
  })
  if f.properties.hide then
    vars.article = false
  end
  self.site:write_data(vars.url, pandoc.layout.render(render(vars), 72))
end

function Builder:run()
  local vars = {
    current_year = os.date("%Y"),
  }

  for f in self.vault:notes():iter() do
    self:make_page(vars, f)
  end
end

local b = Builder.new(arg[1], arg[2])
b:run()
b.site:cleanup()
