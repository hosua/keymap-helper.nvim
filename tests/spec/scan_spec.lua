local scan = require "keymap-helper.scan"
local config = require "keymap-helper.config"

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h")

local function parse_fixture()
  local lines = assert(scan.read_lines(root .. "/fixtures/mappings.lua"))
  return scan.parse(lines, {
    header_pattern = config.defaults.header_pattern,
    map_functions = config.defaults.map_functions,
    fallback_group = "Misc",
  })
end

describe("scan.parse", function()
  it("reads every map call with its header group, modes, lhs and desc", function()
    eq({
      { group = "General", modes = "n", lhs = ";", desc = "CMD enter command mode" },
      { group = "General", modes = "i", lhs = "jk", desc = "" },
      { group = "Git  (<leader>g)", modes = "n,x", lhs = "<leader>gb", desc = "git blame line" },
      { group = "Git  (<leader>g)", modes = "n", lhs = "<leader>gd", desc = "" },
      { group = "Git  (<leader>g)", modes = "n", lhs = "<C-h>", desc = "window left" },
      { group = "Git  (<leader>g)", modes = "v", lhs = "<leader>gy", desc = "yank permalink" },
    }, parse_fixture())
  end)

  it("never borrows the desc of the next call", function()
    local entries = parse_fixture()
    eq("", entries[4].desc)
  end)

  it("uses the fallback group before the first header", function()
    local entries = scan.parse({ 'map("n", "x", "y", { desc = "d" })' }, {
      header_pattern = config.defaults.header_pattern,
      map_functions = { "map" },
      fallback_group = "Misc",
    })
    eq("Misc", entries[1].group)
  end)

  it("only recognises the configured function names", function()
    local entries = scan.parse({ 'nmap("n", "x", "y", { desc = "d" })' }, {
      header_pattern = config.defaults.header_pattern,
      map_functions = { "map" },
      fallback_group = "Misc",
    })
    eq({}, entries)
  end)

  it("read_lines reports a missing file instead of throwing", function()
    local lines, err = scan.read_lines "/nonexistent/keymap-helper"
    eq(nil, lines)
    ok(err)
  end)
end)
