local layout = require "keymap-helper.ui.layout"

describe("ui.layout.toast", function()
  it("centers a 54x3 box in 80x24", function()
    eq({ row = 9, col = 12, width = 54, height = 3 }, layout.toast(54, 3, 80, 24, "center"))
  end)

  it("centers a 54x3 box in 200x50", function()
    eq({ row = 22, col = 72, width = 54, height = 3 }, layout.toast(54, 3, 200, 50, "center"))
  end)

  it("puts a 54x3 box bottom-right in 80x24", function()
    eq({ row = 17, col = 23, width = 54, height = 3 }, layout.toast(54, 3, 80, 24, "bottom_right"))
  end)

  it("puts a 54x3 box bottom-right in 200x50", function()
    eq({ row = 43, col = 143, width = 54, height = 3 }, layout.toast(54, 3, 200, 50, "bottom_right"))
  end)

  it("clamps an oversized box to a tiny 10x5 editor (center)", function()
    eq({ row = 1, col = 1, width = 6, height = 1 }, layout.toast(54, 20, 10, 5, "center"))
  end)

  it("clamps an oversized box to a tiny 10x5 editor (bottom_right)", function()
    eq({ row = 0, col = 1, width = 6, height = 1 }, layout.toast(54, 20, 10, 5, "bottom_right"))
  end)

  it("never returns a negative row/col or a zero size, even in a 4x3 editor", function()
    for _, pos in ipairs { "center", "bottom_right" } do
      local r = layout.toast(54, 3, 4, 3, pos)
      eq({ row = 0, col = 0, width = 1, height = 1 }, r)
    end
  end)

  it("keeps the box inside the editor including its border", function()
    for _, size in ipairs { { 80, 24 }, { 200, 50 }, { 10, 5 }, { 30, 8 } } do
      for _, pos in ipairs { "center", "bottom_right" } do
        local r = layout.toast(54, 3, size[1], size[2], pos)
        ok(r.row >= 0 and r.col >= 0, pos)
        ok(r.col + r.width + 2 <= size[1], ("%s %dx%d right edge"):format(pos, size[1], size[2]))
        ok(r.row + r.height + 2 <= size[2], ("%s %dx%d bottom edge"):format(pos, size[1], size[2]))
      end
    end
  end)

  it("falls back to center for an unknown position", function()
    eq(layout.toast(54, 3, 80, 24, "center"), layout.toast(54, 3, 80, 24, "nowhere"))
    eq(layout.toast(54, 3, 200, 50, "center"), layout.toast(54, 3, 200, 50, nil))
  end)
end)
