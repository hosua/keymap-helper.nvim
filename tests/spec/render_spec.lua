local render = require "keymap-helper.render"

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

  it("produces the same layout as the original config module", function()
    eq({
      "  Custom  ·  lua/mappings.lua",
      "",
      "  General",
      "    n     ;                      cmd",
      "",
      "  Git",
      "    n,x   <leader>gb             blame",
      "",
      "  Default",
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
    }, r.spans)
  end)

  it("records a hit region per section header", function()
    eq({ { row = 0, kind = "section", id = 1 }, { row = 8, kind = "section", id = 2 } }, r.regions)
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
    eq("  How to read this list", r.lines[1])
    eq(intro.lines, { unpack(r.lines, 2, 8) })
    eq("", r.lines[9])
    eq("  Custom", r.lines[10])
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
    eq("  Custom", render.render(plain).lines[1])
  end)
end)
