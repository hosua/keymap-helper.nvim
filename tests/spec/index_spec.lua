local index = require "keymap-helper.index"
local config = require "keymap-helper.config"

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h:h")
local dir = root .. "/tests/fixtures/classify/config"

local function ident(s)
  return s
end

describe("index.list_files", function()
  it("lists lua files sorted, skipping node_modules", function()
    eq({ dir .. "/init.lua", dir .. "/lua/mappings.lua" }, (index.list_files(dir, 50)))
    local _, capped = index.list_files(dir, 50)
    eq(false, capped)
  end)

  it("caps at max_files and says so", function()
    local files, capped = index.list_files(dir, 1)
    eq(1, #files)
    eq(true, capped)
  end)

  it("returns nothing for a missing dir", function()
    local files, capped = index.list_files(dir .. "/nope", 5)
    eq({}, files)
    eq(false, capped)
  end)
end)

describe("index.from_parsed", function()
  it("numbers entries, first wins, splits modes, empty group is nil", function()
    local parsed = {
      {
        file = "/a.lua",
        entries = {
          { group = "", modes = "n", lhs = "a", desc = "" },
          { group = "G", modes = "n,x", lhs = "b", desc = "" },
          { group = "H", modes = "n", lhs = "a", desc = "" },
        },
      },
    }
    eq({
      na = { file = "/a.lua", order = 1 },
      nb = { file = "/a.lua", group = "G", order = 2 },
      xb = { file = "/a.lua", group = "G", order = 2 },
    }, index.from_parsed(parsed, ident))
  end)
end)

describe("index.build", function()
  it("indexes the fixture config dir", function()
    local init, maps = dir .. "/init.lua", dir .. "/lua/mappings.lua"
    local idx, stats = index.build(dir, {
      header_pattern = config.defaults.header_pattern,
      map_functions = config.defaults.map_functions,
      max_files = 50,
    }, ident)
    local fg = { file = maps, group = "Files", order = 3 }
    eq({
      ["n<leader>ia"] = { file = init, order = 1 },
      ["n<leader>ff"] = { file = maps, group = "Files", order = 2 },
      ["n<leader>fg"] = fg,
      ["x<leader>fg"] = fg,
      ["n<leader>gs"] = { file = maps, group = "Git", order = 4 },
    }, idx)
    eq({ files = 2, capped = false }, stats)
  end)
end)
