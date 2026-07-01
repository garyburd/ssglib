-- Generate API.md from ssglib's source.
--
-- Export lua-language-server docs, expand template `eval` blocks with
-- ssglib.filters, prepend contents, and write GitHub-flavored Markdown.
--
-- Run from the repository root:  pandoc-lua docgen/main.lua

local pandoc = require "pandoc"
local filters = require "ssglib.filters"

local lib_src = "ssglib" -- documented modules
local template = "docgen/template.md" -- prose template
local output = "API.md" -- generated reference

-- ===========================================================================
-- Load doc.json from lua-language-server
-- ===========================================================================

--- Export and load lua-language-server docs.
--- @param src string Library source directory to document
--- @return table docs Decoded doc.json type entries
local function load_docs(src)
  local docs
  pandoc.system.with_temporary_directory("ssglib-doc", function(tmp)
    pandoc.system.command("lua-language-server", { "--doc", src, "--doc_out_path", tmp }, "")
    local ok, data = pcall(pandoc.system.read_file, pandoc.path.join { tmp, "doc.json" })
    if not ok then
      error("doc.json not produced; is lua-language-server installed?")
    end
    docs = pandoc.json.decode(data, false)
  end)
  return docs
end

-- ===========================================================================
-- API renderers (return pandoc Blocks)
-- ===========================================================================

--- Build documentation renderers over the loaded docs.
--- @param docs table Decoded doc.json
--- @return table api
local function build_api(docs)
  local index = {}
  for _, entry in ipairs(docs) do
    index[entry.name] = entry
  end

  -- Markdown → Blocks.
  local function blocks_of(text)
    return pandoc.read(text or "", "markdown").blocks
  end

  -- Markdown → the first block's Inlines.
  local function inlines_of(text)
    local bs = pandoc.read(text or "", "markdown").blocks
    if bs[1] and bs[1].content then
      return bs[1].content
    end
    return { pandoc.Str(text or "") }
  end

  -- Trimmed description before the first annotation.
  local function lead(desc)
    desc = desc or ""
    local cut = desc:find("@%*?%a")
    if cut then
      desc = desc:sub(1, cut - 1)
    end
    return (desc:gsub("^%s+", ""):gsub("%s+$", ""))
  end

  -- Short owner name: "ssglib.Site" → "Site".
  local function short(name)
    return name:match("[^.]+$")
  end

  -- Document assignments, excluding class state, private fields, and internals.
  local function is_member(f)
    local t = f.type
    return (t == "setfield" or t == "setmethod")
      and f.name:sub(1, 1) ~= "_"
      and f.visible ~= "private"
  end

  local function is_function(f)
    return type(f.extends) == "table" and f.extends.type == "function"
  end

  -- Extract argument names when LuaLS leaves a function as a view string.
  local function args_from_view(view)
    local inside = view and view:match("^fun%((.-)%)")
    if not inside or inside == "" then
      return nil
    end
    local names = {}
    for part in (inside .. ","):gmatch("(.-),") do
      local nm = part:match("^%s*([%w_]+)")
      if nm then
        names[#names + 1] = nm
      end
    end
    return names
  end

  -- A `name type — description` bullet.
  local function arg_item(name, typ, desc)
    local inlines = { pandoc.Code(name and name ~= "" and name or "...") }
    if typ and typ ~= "" and typ ~= "unknown" then
      inlines[#inlines + 1] = pandoc.Str(" ")
      inlines[#inlines + 1] = pandoc.Code(typ)
    end
    if desc and desc ~= "" then
      inlines[#inlines + 1] = pandoc.Str(" — ")
      for _, inl in ipairs(inlines_of(desc)) do
        inlines[#inlines + 1] = inl
      end
    end
    return pandoc.Plain(inlines)
  end

  -- Render one member at the given heading level.
  local function render_member(owner, f, level)
    local ext = f.extends or {}
    local blocks = {}

    -- Signature heading.
    local sig
    if is_function(f) then
      local args, method = ext.args or {}, false
      local names = {}
      for i, a in ipairs(args) do
        if i == 1 and a.name == "self" then
          method = true
        else
          names[#names + 1] = a.name
        end
      end
      sig = short(owner) .. (method and ":" or ".") .. f.name .. "(" .. table.concat(names, ", ") .. ")"
    else
      local names = args_from_view(ext.view)
      sig = short(owner) .. "." .. f.name .. (names and ("(" .. table.concat(names, ", ") .. ")") or "")
    end
    blocks[#blocks + 1] = pandoc.Header(level, { pandoc.Str(sig) })

    -- Markdown description without annotations.
    for _, b in ipairs(blocks_of(lead(f.desc))) do
      blocks[#blocks + 1] = b
    end

    -- Expanded function parameters and returns.
    if is_function(f) then
      local params = {}
      for i, a in ipairs(ext.args or {}) do
        if not (i == 1 and a.name == "self") then
          params[#params + 1] = arg_item(a.name, a.view, a.desc)
        end
      end
      if #params > 0 then
        blocks[#blocks + 1] = pandoc.Para { pandoc.Strong { pandoc.Str("Parameters") } }
        blocks[#blocks + 1] = pandoc.BulletList(params)
      end
      local rets = {}
      for _, r in ipairs(ext.returns or {}) do
        rets[#rets + 1] = arg_item(r.name or "", r.view, r.desc)
      end
      if #rets > 0 then
        blocks[#blocks + 1] = pandoc.Para { pandoc.Strong { pandoc.Str("Returns") } }
        blocks[#blocks + 1] = pandoc.BulletList(rets)
      end
    end

    return blocks
  end

  -- Public members in source order.
  local function members_of(entry)
    local members = {}
    for _, f in ipairs(entry.fields or {}) do
      if is_member(f) then
        members[#members + 1] = f
      end
    end
    table.sort(members, function(a, b)
      return (a.start and a.start[1] or 0) < (b.start and b.start[1] or 0)
    end)
    return members
  end

  -- Ordered `{ type name, display title }` pairs.
  local manual = {
    { "ssglib.Vault", "Vault" },
    { "ssglib.Site", "Site" },
    { "ssglib.elements", "Elements" },
    { "ssglib.filters", "Filters" },
    { "ssglib.paths", "Paths" },
    { "ssglib.rss", "RSS" },
    { "ssglib.gallery", "Gallery" },
  }

  local api = {}

  --- Render modules as level-2 sections and members as level-3 sections.
  --- @return pandoc.Blocks
  function api.reference()
    local blocks = {}
    for _, m in ipairs(manual) do
      local name, title = m[1], m[2]
      local entry = index[name]
      if entry then
        blocks[#blocks + 1] = pandoc.Header(2, { pandoc.Str(title) })
        for _, b in ipairs(blocks_of(lead(entry.desc))) do
          blocks[#blocks + 1] = b
        end
        for _, f in ipairs(members_of(entry)) do
          for _, b in ipairs(render_member(name, f, 3)) do
            blocks[#blocks + 1] = b
          end
        end
      end
    end
    return pandoc.Blocks(blocks)
  end

  return api
end

-- ===========================================================================
-- Table of contents (GitHub-compatible anchors)
-- ===========================================================================

--- Create a GitHub-style header slug and number duplicates.
--- @param text string
--- @param seen table<string, integer> Mutable slug counts
--- @return string
local function gh_slug(text, seen)
  local s = text:lower():gsub("[^%w%s_-]", ""):gsub("%s", "-")
  if seen[s] == nil then
    seen[s] = 0
    return s
  end
  seen[s] = seen[s] + 1
  return s .. "-" .. seen[s]
end

--- Prepend contents linking to every level-2 and level-3 header.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function add_toc(doc)
  local seen, entries = {}, {}
  doc:walk {
    Header = function(h)
      if h.level == 2 or h.level == 3 then
        -- Use plain header text for the slug and label.
        local text = pandoc.utils.stringify(h.content)
        entries[#entries + 1] = {
          level = h.level,
          slug = gh_slug(text, seen),
          text = text,
        }
      end
    end,
  }

  -- Build a two-level link list.
  local top = {}
  for _, e in ipairs(entries) do
    local link = pandoc.Link({ pandoc.Str(e.text) }, "#" .. e.slug)
    if e.level == 2 then
      top[#top + 1] = { plain = pandoc.Plain { link }, subs = {} }
    elseif #top > 0 then
      table.insert(top[#top].subs, pandoc.Plain { link })
    end
  end
  local items = {}
  for _, t in ipairs(top) do
    local item = pandoc.List { t.plain }
    if #t.subs > 0 then
      item:insert(pandoc.BulletList(t.subs))
    end
    items[#items + 1] = item
  end

  -- Insert contents before the first level-2 header.
  local idx
  for i, b in ipairs(doc.blocks) do
    if b.tag == "Header" and b.level == 2 then
      idx = i
      break
    end
  end
  local head = pandoc.Header(2, { pandoc.Str "Contents" })
  local toc = pandoc.BulletList(items)
  if idx then
    doc.blocks:insert(idx, toc)
    doc.blocks:insert(idx, head)
  else
    doc.blocks:insert(head)
    doc.blocks:insert(toc)
  end
  return doc
end

-- ===========================================================================
-- Generate
-- ===========================================================================

local api = build_api(load_docs(lib_src))
local doc = pandoc.read(pandoc.system.read_file(template), "markdown")
doc = doc:walk { CodeBlock = filters.make_codeblock_filter { api = api } }
doc = add_toc(doc)
local markdown = pandoc.write(doc, "gfm")

if arg[1] == "--check" then
  -- Fail when generated output has drifted.
  local current = ""
  pcall(function()
    current = pandoc.system.read_file(output)
  end)
  if current ~= markdown then
    io.stderr:write(string.format("%s is out of date; run `make api`.\n", output))
    os.exit(1)
  end
  io.stdout:write(string.format("%s is up to date.\n", output))
else
  pandoc.system.write_file(output, markdown)
  io.stdout:write(string.format("wrote %s\n", output))
end
