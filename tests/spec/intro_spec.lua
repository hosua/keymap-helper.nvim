local intro = require "keymap-helper.intro"

local TAIL = {
  "",
  "    Modes   n normal · i insert · v visual+select · x visual · s select",
  "            o operator-pending · t terminal · c command-line",
  "            n,x = several modes · ! = insert+command-line",
  "    Keys    <C-x> Ctrl+x · <M-x>/<A-x> Alt+x · <S-x> Shift+x · <CR> Enter · <BS> Backspace",
}

local function head(leader, localleader)
  return {
    ("    %-14s %-12s %s"):format("<leader>", leader, "prefix for most custom maps (vim.g.mapleader)"),
    ("    %-14s %-12s %s"):format(
      "<localleader>",
      localleader,
      "prefix for filetype-local maps (vim.g.maplocalleader)"
    ),
  }
end

describe("intro.describe_key", function()
  it("shows nil as the default leader", function()
    eq("\\ (default)", intro.describe_key(nil))
  end)

  it("shows space as <Space>", function()
    eq("<Space>", intro.describe_key " ")
  end)

  it("leaves plain keys alone", function()
    eq(",", intro.describe_key ",")
  end)

  it("keytrans special keys", function()
    eq("<Tab>", intro.describe_key "\t")
  end)
end)

describe("intro.build", function()
  it("has the fixed title", function()
    eq("How to read this list", intro.build(" ", nil).title)
  end)

  it("produces all 7 lines for leader <Space> and no localleader", function()
    local expected = head("<Space>", "\\ (default)")
    vim.list_extend(expected, TAIL)
    eq(7, #expected)
    eq(expected, intro.build(" ", nil).lines)
  end)

  it("describes custom leader and localleader in the first two lines", function()
    local lines = intro.build(",", "\\").lines
    local expected = head(",", "\\")
    eq(expected[1], lines[1])
    eq(expected[2], lines[2])
    eq(7, #lines)
  end)

  it("describes an unset leader as the default", function()
    local lines = intro.build(nil, nil).lines
    local expected = head("\\ (default)", "\\ (default)")
    eq(expected[1], lines[1])
    eq(expected[2], lines[2])
    eq(TAIL, { unpack(lines, 3) })
  end)
end)
