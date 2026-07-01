--- Generate RSS 2.0 feeds.
--- Dependencies: Pandoc

local parent = (...):match("(.-%.).+$") or ""
local elements = require(parent .. "elements")
local pandoc = require "pandoc"

local html = elements.html
local xml = elements.xml
local raw = elements.raw
local concat = elements.concat

-- RFC 822 requires English names; `os.date` `%a` and `%b` depend on locale.
local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

--- Format an ISO 8601 date as an RFC 822 pubDate (UTC midnight).
---@param date string Date in ISO 8601 format (YYYY-MM-DD)
---@return string pubdate RFC 822 date, e.g. "Mon, 02 Jan 2006 00:00:00 +0000"
local function rfc822_date(date)
  local year, month, day = date:match("(%d%d%d%d)-(%d%d)-(%d%d)")
  -- `os.time` uses local time and defaults to noon, keeping UTC's numeric
  -- weekday on the same date in every real-world time zone (within ±12 hours).
  local wday = tonumber(os.date("!%w", os.time { year = year, month = month, day = day }))
  return string.format("%s, %s %s %s 00:00:00 +0000", WEEKDAYS[wday + 1], day, MONTHS[tonumber(month)], year)
end

--- Generate RSS 2.0 feeds.
---@class ssglib.rss
local M = {}

--- Return an RSS-discovery `<link>` for an HTML `<head>`.
---
---@param url string Feed URL (e.g. "/feed.xml")
---@param channel table Channel metadata with `title`
---@return table layout.Doc
function M.head_link(url, channel)
  return html.link {
    rel = "alternate",
    type = "application/rss+xml",
    title = channel.title,
    href = url,
  }
end

--- Write an RSS 2.0 feed to the site.
---
--- `items` should come from `query_base()` with these base fields:
---
---   - path (string): vault-relative note path (e.g. "articles/My Post.md")
---   - "file name" (string): note title (built-in base attribute)
---   - date (string): ISO 8601 publication date (YYYY-MM-DD)
---   - description (string): plain-text summary
---
---@param site ssglib.Site Destination site
---@param vault ssglib.Vault Vault for resolving note URLs
---@param url string Feed URL (e.g. "/feed.xml")
---@param channel table Channel title, link, and description
---   - title (string): feed title
---   - link (string): site URL without a trailing slash (e.g. "https://example.com")
---   - description (string): feed description
---@param items pandoc.List `query_base()` results with the fields above
function M.write_rss(site, vault, url, channel, items)
  local feed_items = {}
  for _, item in ipairs(items) do
    local item_url = channel.link .. vault:url(item.path)
    table.insert(feed_items, xml.item {
      xml.title { item["file name"] },
      xml.link { item_url },
      xml.description { item.description or "" },
      xml.pubDate { rfc822_date(item.date) },
      xml.guid { isPermaLink = "true", item_url },
    })
  end

  local feed = concat {
    raw '<?xml version="1.0" encoding="UTF-8"?>\n',
    xml.rss {
      version = "2.0",
      xml.channel {
        xml.title { channel.title },
        xml.link { channel.link },
        xml.description { channel.description or "" },
        concat(feed_items),
      },
    },
  }

  site:write_data(url, pandoc.layout.render(feed))
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return M
