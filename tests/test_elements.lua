-- Test suite for elements module

local pandoc = require "pandoc"
local layout = pandoc.layout
local elements = require "ssglib.elements"
local test = require "tests.test"
local html = elements.html
local xml = elements.xml

local assert_equals = test.assert_equals

local function render(doc)
  -- Use large width (1000) to prevent Pandoc from wrapping HTML lines
  return layout.render(doc, 1000)
end

-- ============================================================================
-- Test Suites
-- ============================================================================

local basic_content_tests = {
  "simple span",
  function()
    assert_equals(render(html.span { "hello" }), "<span>hello</span>")
  end,

  "nested elements",
  function()
    assert_equals(render(html.div { html.span { "text" } }), "<div><span>text</span></div>\n")
  end,

  "multiple children",
  function()
    assert_equals(render(html.p { "first", " ", "second" }), "<p>first second</p>\n")
  end,
}

local attribute_tests = {
  "single class",
  function()
    assert_equals(render(html.span { class = "my-class", "text" }), '<span class="my-class">text</span>')
  end,

  "multiple attributes (sorted alphabetically)",
  function()
    assert_equals(render(html.a { href = "url", id = "link", "click" }), '<a href="url" id="link">click</a>')
  end,

  "boolean true attribute",
  function()
    assert_equals(render(html.input { checked = true, type = "checkbox" }), '<input checked type="checkbox">')
  end,

  "boolean false attribute (ignored)",
  function()
    assert_equals(render(html.input { disabled = false, type = "text" }), '<input type="text">')
  end,

  "numeric attribute",
  function()
    assert_equals(render(html.div { ["data-count"] = 42 }), '<div data-count="42"></div>\n')
  end,

  "underbar converted to dash",
  function()
    assert_equals(render(html.div { data_count = 42 }), '<div data-count="42"></div>\n')
  end,

  "double underbar converted to single underbar",
  function()
    assert_equals(render(html.div { data_x__y = "xy" }), '<div data-x_y="xy"></div>\n')
  end,
}

local escaping_tests = {
  "escape content",
  function()
    assert_equals(render(html.span { "if 1 < 2 & 3 > 2" }), "<span>if 1 &lt; 2 &amp; 3 &gt; 2</span>")
  end,

  "escape attribute",
  function()
    assert_equals(render(html.div { title = 'key "quote"' }), '<div title="key &quot;quote&quot;"></div>\n')
  end,

  "newline in attribute (replaced by space)",
  function()
    assert_equals(render(html.div { title = "line1\nline2" }), '<div title="line1 line2"></div>\n')
  end,

  "special characters in content",
  function()
    assert_equals(
      render(html.p { "<script>alert('xss')</script>" }),
      "<p>&lt;script&gt;alert('xss')&lt;/script&gt;</p>\n"
    )
  end,
}

local void_tag_tests = {
  "br",
  function()
    assert_equals(render(html.br {}), "<br>\n")
  end,

  "img with attributes",
  function()
    assert_equals(render(html.img { src = "pic.jpg" }), '<img src="pic.jpg">')
  end,

  "hr",
  function()
    assert_equals(render(html.hr {}), "<hr>\n")
  end,

  "input",
  function()
    assert_equals(render(html.input { type = "text", name = "field" }), '<input name="field" type="text">')
  end,

  "void tag ignores content",
  function()
    assert_equals(render(html.br { "Content ignored" }), "<br>\n")
  end,
}

local xml_mode_tests = {
  "self-closing empty tag",
  function()
    assert_equals(render(xml.foo {}), "<foo/>")
  end,

  "tag with content",
  function()
    assert_equals(render(xml.foo { "bar" }), "<foo>bar</foo>")
  end,

  "tag with attributes",
  function()
    assert_equals(render(xml.item { id = "1" }), '<item id="1"/>')
  end,

  "nested xml elements",
  function()
    assert_equals(render(xml.parent { xml.child { "text" } }), "<parent><child>text</child></parent>")
  end,
}

local utility_tests = {
  "concat with separator",
  function()
    assert_equals(render(elements.concat({ "a", "b" }, "|")), "a|b")
  end,

  "raw",
  function()
    assert_equals(render(elements.concat { elements.raw("><") }), "><")
  end,
}

local complex_structure_tests = {
  "nested divs with classes",
  function()
    assert_equals(
      render(html.div {
        class = "outer",
        html.div { class = "inner", "content" },
      }),
      '<div class="outer">\n<div class="inner">content</div>\n</div>\n'
    )
  end,

  "list structure",
  function()
    assert_equals(
      render(html.ul {
        html.li { "first" },
        html.li { "second" },
      }),
      "<ul>\n<li>first</li>\n<li>second</li>\n</ul>\n"
    )
  end,

  "table structure",
  function()
    assert_equals(
      render(html.table {
        html.tr {
          html.td { "cell1" },
          html.td { "cell2" },
        },
      }),
      "<table><tr><td>cell1</td><td>cell2</td></tr></table>"
    )
  end,
}

-- ============================================================================
-- Run All Tests
-- ============================================================================

local all_tests = {
  "basic_content",
  basic_content_tests,

  "attributes",
  attribute_tests,

  "escaping",
  escaping_tests,

  "void_elements",
  void_tag_tests,

  "xml_mode",
  xml_mode_tests,

  "utilities",
  utility_tests,

  "complex_structures",
  complex_structure_tests,
}

if not test.run_tests("", all_tests) then
  os.exit(1)
end
