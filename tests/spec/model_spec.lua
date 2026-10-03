local model = require "keymap-helper.model"

local function ident(s)
  return s
end

local cfg = {
  sections = {
    { title = "Custom", subtitle = "lua/mappings.lua", group_by = "header" },
    { title = "Plugin" },
    { title = "Default", rest = true },
  },
  window = { footer = "q to close" },
}

local data = {
  scanned = {
    {
      { group = "General", modes = "n", lhs = "a", desc = "first" },
      { group = "General", modes = "n,x", lhs = "b", desc = "second" },
      { group = "Git", modes = "n", lhs = "c", desc = "third" },
    },
    { { group = "Plugin", modes = "i", lhs = "d", desc = "plugin map" } },
  },
  live = {
    { mode = "n", lhs = "a", desc = "first" }, -- claimed by Custom
    { mode = "x", lhs = "b", desc = "second" }, -- claimed via "n,x"
    { mode = "i", lhs = "d", desc = "plugin map" }, -- claimed by Plugin
    { mode = "n", lhs = "z", desc = "zeta" },
    { mode = "n", lhs = "e", desc = "echo" },
    { mode = "v", lhs = "e", desc = "echo v" },
    { mode = "n", lhs = "nodesc" },
  },
}

describe("model.build", function()
  local state = model.build(cfg, data, ident, ident)

  it("groups file sections by header, in file order", function()
    local custom = state.sections[1]
    eq({ "General", "Git" }, { custom.groups[1].title, custom.groups[2].title })
    eq(2, #custom.groups[1].rows)
    eq(3, custom.count)
  end)

  it("leaves ungrouped sections as one untitled group", function()
    eq({ { rows = { { modes = "i", lhs = "d", desc = "plugin map" } } } }, state.sections[2].groups)
  end)

  it("puts only unclaimed, described live maps in the rest section, sorted", function()
    eq({
      { modes = "n", lhs = "e", desc = "echo" },
      { modes = "v", lhs = "e", desc = "echo v" },
      { modes = "n", lhs = "z", desc = "zeta" },
    }, state.sections[3].groups[1].rows)
  end)

  it("keeps section order, ids and the footer", function()
    eq(
      { 1, 2, 3 },
      vim.tbl_map(function(s)
        return s.id
      end, state.sections)
    )
    eq("q to close", state.footer)
  end)

  it("renders an empty section with no groups", function()
    local s = model.build(
      { sections = { { title = "Empty" } }, window = {} },
      { scanned = {}, live = {} },
      ident,
      ident
    )
    eq({}, s.sections[1].groups)
    eq(0, s.sections[1].count)
  end)
end)

describe("model.build intro", function()
  local base = vim.tbl_extend("force", cfg, { intro = { enabled = true } })
  local env = { mapleader = " ", maplocalleader = nil }

  it("builds the intro from env when enabled", function()
    local state = model.build(base, data, ident, ident, env)
    eq(require("keymap-helper.intro").build(" ", nil), state.intro)
  end)

  it("has no intro without env", function()
    eq(nil, model.build(base, data, ident, ident).intro)
  end)

  it("has no intro when intro.enabled is false", function()
    local off = vim.tbl_extend("force", cfg, { intro = { enabled = false } })
    eq(nil, model.build(off, data, ident, ident, env).intro)
  end)

  it("has no intro when cfg.intro is absent", function()
    eq(nil, model.build(cfg, data, ident, ident, env).intro)
  end)
end)
