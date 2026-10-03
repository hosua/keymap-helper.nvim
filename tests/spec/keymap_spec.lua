vim.g.mapleader = " "

local LHS = { "<leader>km", "<leader>k?", "<leader>ku" }

local function rhs(lhs)
  return vim.fn.maparg(lhs, "n", false, true).rhs
end

--- Forget what the module mapped and unmap every key this spec touches, so each
--- case starts from a module that has never run.
local function fresh()
  for _, lhs in ipairs(LHS) do
    pcall(vim.keymap.del, "n", lhs)
  end
  package.loaded["keymap-helper.keymap"] = nil
  return require "keymap-helper.keymap"
end

describe("keymap", function()
  it("DEFAULT is <leader>km and matches the config default", function()
    local km = fresh()
    eq("<leader>km", km.DEFAULT)
    eq(km.DEFAULT, require("keymap-helper.config").defaults.keymap)
  end)

  it("apply() maps the default key to :KeymapHelper with a description", function()
    local km = fresh()
    eq("<leader>km", km.apply())
    eq("<cmd>KeymapHelper<cr>", rhs "<leader>km")
    eq("show the keymap list", vim.fn.maparg("<leader>km", "n", false, true).desc)
  end)

  it("apply() twice is a no-op returning the same lhs", function()
    local km = fresh()
    eq("<leader>km", km.apply())
    eq("<leader>km", km.apply())
    eq("<cmd>KeymapHelper<cr>", rhs "<leader>km")
  end)

  it("moves the map when a new key is requested", function()
    local km = fresh()
    km.apply()
    eq("<leader>k?", km.apply "<leader>k?")
    eq(nil, rhs "<leader>km")
    eq("<cmd>KeymapHelper<cr>", rhs "<leader>k?")
  end)

  it("apply(false) removes the map and a later apply() stays unmapped", function()
    local km = fresh()
    km.apply()
    eq(nil, km.apply(false))
    eq(nil, rhs "<leader>km")
    eq(nil, km.apply())
    eq(nil, rhs "<leader>km")
  end)

  it("never overwrites a key the user already mapped", function()
    local km = fresh()
    vim.keymap.set("n", "<leader>ku", "<cmd>echo 1<cr>")
    eq(nil, km.apply "<leader>ku")
    eq("<cmd>echo 1<cr>", rhs "<leader>ku")
  end)

  it("does not delete a key the user remapped after the plugin mapped it", function()
    local km = fresh()
    km.apply()
    vim.keymap.set("n", "<leader>km", "<cmd>echo 2<cr>")
    km.apply(false)
    eq("<cmd>echo 2<cr>", rhs "<leader>km")
  end)

  it("collect.command_key() finds the mapped key", function()
    local km = fresh()
    km.apply()
    eq("<leader>km", require("keymap-helper.collect").command_key())
  end)

  it("setup() honours the keymap option", function()
    local km = fresh()
    require("keymap-helper").setup { keymap = false, hint = { enabled = false } }
    eq(nil, rhs "<leader>km")
    require("keymap-helper").setup { keymap = "<leader>k?", hint = { enabled = false } }
    eq("<cmd>KeymapHelper<cr>", rhs "<leader>k?")
    eq(nil, rhs "<leader>km")
    km.apply(false)
    eq(nil, rhs "<leader>k?")
  end)
end)
