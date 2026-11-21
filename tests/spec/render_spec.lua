local render = require "keymap-helper.render"

local ROW_HL = { KeymapHelperMode = true, KeymapHelperKey = true, KeymapHelperDesc = true }

-- Whole-line spans only (headers, groups, footer); row spans have their own test.
local function no_chevron(spans)
  return vim.tbl_filter(function(sp)
    return sp.hl ~= "KeymapHelperChevron" and not ROW_HL[sp.hl]
  end, spans)
end

local function row_spans(spans, row)
  return vim.tbl_filter(function(sp)
    return sp.row == row and ROW_HL[sp.hl]
  end, spans)
end

describe("render", function()
  local state = {
    sections = {
      {
        id = 1,
        title = "Custom",
        subtitle = "lua/mappings.lua",
        count = 2,
        groups = {
          { title = "General", rows = { { modes = "n", lhs = ";", desc = "cmd" } } },
          { title = "Git", rows = { { modes = "n,x", lhs = "<leader>gb", desc = "blame" } } },
        },
      },
      { id = 2, title = "Default", count = 1, groups = { { rows = { { modes = "n", lhs = "Y", desc = "yank" } } } } },
    },
    footer = "q or <Esc> to close",
  }
  local r = render.render(state)

  it("renders expanded sections with a down chevron when view is nil", function()
    eq({
      "  ▾ Custom (2)  ·  lua/mappings.lua",
      "",
      "  General",
      "    n     ;                      cmd",
      "",
      "  Git",
      "    n,x   <leader>gb             blame",
      "",
      "  ▾ Default (1)",
      "    n     Y                      yank",
      "",
      "  q or <Esc> to close",
    }, r.lines)
  end)

  it("highlights section, group and footer lines", function()
    eq({
      { row = 0, col_start = 0, col_end = -1, hl = "KeymapHelperSection" },
      { row = 2, col_start = 0, col_end = -1, hl = "KeymapHelperGroup" },
      { row = 5, col_start = 0, col_end = -1, hl = "KeymapHelperGroup" },
      { row = 8, col_start = 0, col_end = -1, hl = "KeymapHelperSection" },
      { row = 11, col_start = 0, col_end = -1, hl = "KeymapHelperFooter" },
    }, no_chevron(r.spans))
  end)

  it("highlights each row's modes, key and description separately", function()
    -- "    n,x   <leader>gb             blame"
    eq({
      { row = 6, col_start = 4, col_end = 7, hl = "KeymapHelperMode" },
      { row = 6, col_start = 10, col_end = 20, hl = "KeymapHelperKey" },
      { row = 6, col_start = 33, col_end = -1, hl = "KeymapHelperDesc" },
    }, row_spans(r.spans, 6))
  end)

  it("pads by display width and skips the span of an empty description", function()
    local wide = render.render {
      sections = {
        {
          id = 1,
          title = "S",
          count = 2,
          groups = {
            {
              rows = {
                { modes = "n", lhs = "é│", desc = "wide" },
                { modes = "i", lhs = "jk", desc = "" },
              },
            },
          },
        },
      },
    }
    eq(vim.fn.strdisplaywidth "    n     ;                      wide", vim.fn.strdisplaywidth(wide.lines[2]))
    eq(2, #row_spans(wide.spans, 2))
  end)

  it("records a hit region per section header", function()
    eq({ { row = 0, kind = "section", id = 1 }, { row = 8, kind = "section", id = 2 } }, r.regions)
  end)

  it("honours each section's own collapsed flag when view is nil", function()
    local s = vim.deepcopy(state)
    s.sections[2].collapsed = true
    eq("  ▸ Default (1)", render.render(s).lines[9])
  end)

  it("view overrides the section's own collapsed flag", function()
    local s = vim.deepcopy(state)
    s.sections[1].collapsed = true
    local rr = render.render(s, { collapsed = { [1] = false, [2] = false } })
    eq(r.lines, rr.lines)
  end)

  describe("second section collapsed", function()
    local rc = render.render(state, { collapsed = { [1] = false, [2] = true } })

    it("shows only the header line for the collapsed section", function()
      eq({
        "  ▾ Custom (2)  ·  lua/mappings.lua",
        "",
        "  General",
        "    n     ;                      cmd",
        "",
        "  Git",
        "    n,x   <leader>gb             blame",
        "",
        "  ▸ Default (1)",
        "",
        "  q or <Esc> to close",
      }, rc.lines)
    end)

    it("keeps spans and regions consistent", function()
      eq({
        { row = 0, col_start = 0, col_end = -1, hl = "KeymapHelperSection" },
        { row = 2, col_start = 0, col_end = -1, hl = "KeymapHelperGroup" },
        { row = 5, col_start = 0, col_end = -1, hl = "KeymapHelperGroup" },
        { row = 8, col_start = 0, col_end = -1, hl = "KeymapHelperSection" },
        { row = 10, col_start = 0, col_end = -1, hl = "KeymapHelperFooter" },
      }, no_chevron(rc.spans))
      eq({ { row = 0, kind = "section", id = 1 }, { row = 8, kind = "section", id = 2 } }, rc.regions)
    end)
  end)

  describe("all collapsed", function()
    local ra = render.render(state, { collapsed = { [1] = true, [2] = true } })

    it("shows only headers and the footer", function()
      eq({
        "  ▸ Custom (2)  ·  lua/mappings.lua",
        "",
        "  ▸ Default (1)",
        "",
        "  q or <Esc> to close",
      }, ra.lines)
    end)

    it("keeps spans and regions consistent", function()
      eq({
        { row = 0, col_start = 0, col_end = -1, hl = "KeymapHelperSection" },
        { row = 2, col_start = 0, col_end = -1, hl = "KeymapHelperSection" },
        { row = 4, col_start = 0, col_end = -1, hl = "KeymapHelperFooter" },
      }, no_chevron(ra.spans))
      eq({ { row = 0, kind = "section", id = 1 }, { row = 2, kind = "section", id = 2 } }, ra.regions)
    end)
  end)

  describe("section_at / row_of", function()
    it("returns the header's own id on a header row", function()
      eq(1, render.section_at(r, 0))
      eq(2, render.section_at(r, 8))
    end)

    it("returns the nearest header above for rows inside a section body", function()
      eq(1, render.section_at(r, 3))
      eq(1, render.section_at(r, 7))
      eq(2, render.section_at(r, 9))
    end)

    it("returns nil above the first header", function()
      eq(nil, render.section_at(r, -1))
    end)

    it("returns nil on the footer and the blank line above it", function()
      eq(9, r.body_end)
      eq(nil, render.section_at(r, 10))
      eq(nil, render.section_at(r, 11))
    end)

    it("works on collapsed renders", function()
      local ra = render.render(state, { collapsed = { [1] = true, [2] = true } })
      eq(1, render.section_at(ra, 1))
      eq(2, render.section_at(ra, 2))
      eq(nil, render.section_at(ra, 4)) -- footer
    end)

    it("row_of finds a header row or nil", function()
      eq(0, render.row_of(r, 1))
      eq(8, render.row_of(r, 2))
      eq(nil, render.row_of(r, 99))
      local rc = render.render(state, { collapsed = { [1] = true, [2] = false } })
      eq(2, render.row_of(rc, 2))
    end)
  end)
end)

describe("render with intro", function()
  local intro = require("keymap-helper.intro").build(" ", nil)
  local state = {
    intro = intro,
    sections = {
      {
        id = 1,
        title = "Custom",
        count = 1,
        groups = { { title = "General", rows = { { modes = "n", lhs = ";", desc = "cmd" } } } },
      },
    },
    footer = "q or <Esc> to close",
  }
  local r = render.render(state)

  it("emits title, the 7 intro lines, a blank line, then the first section", function()
    eq("  ▾ How to read this list", r.lines[1])
    eq(intro.lines, { unpack(r.lines, 2, 8) })
    eq("", r.lines[9])
    eq("  ▾ Custom (1)", r.lines[10])
    eq("", r.lines[11])
    eq("  General", r.lines[12])
  end)

  it("highlights the title as a section and non-empty intro lines as KeymapHelperIntro", function()
    local function find(row)
      for _, s in ipairs(r.spans) do
        if s.row == row then
          return s
        end
      end
    end
    eq({ row = 0, col_start = 0, col_end = -1, hl = "KeymapHelperSection" }, find(0))
    for i, line in ipairs(intro.lines) do
      if line ~= "" then
        eq({ row = i, col_start = 0, col_end = -1, hl = "KeymapHelperIntro" }, find(i), "intro row " .. i)
      end
    end
  end)

  it("records an intro region at row 0 and shifts section regions", function()
    eq({ { row = 0, kind = "section", id = "intro" }, { row = 9, kind = "section", id = 1 } }, r.regions)
  end)

  it("leaves output without intro unchanged", function()
    local plain = { sections = state.sections, footer = state.footer }
    eq("  ▾ Custom (1)", render.render(plain).lines[1])
  end)

  it("folds the intro to its header, from the state or from the view", function()
    local folded = render.render(vim.tbl_extend("force", state, { intro_collapsed = true }))
    eq({ "  ▸ How to read this list", "", "  ▾ Custom (1)" }, { unpack(folded.lines, 1, 3) })
    eq({ { row = 0, kind = "section", id = "intro" }, { row = 2, kind = "section", id = 1 } }, folded.regions)
    local by_view = render.render(state, { collapsed = { intro = true, [1] = false } })
    eq(folded.lines, by_view.lines)
  end)
end)
