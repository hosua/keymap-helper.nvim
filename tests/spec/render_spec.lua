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
