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

  it("initial_view folds the intro as cfg.intro.collapsed says", function()
    eq(false, model.initial_view(model.build(base, data, ident, ident, env)).collapsed.intro)
    local folded = vim.tbl_extend("force", cfg, { intro = { enabled = true, collapsed = true } })
    eq(true, model.initial_view(model.build(folded, data, ident, ident, env)).collapsed.intro)
    eq(nil, model.initial_view(model.build(cfg, data, ident, ident)).collapsed.intro)
  end)

  it("has no intro when cfg.intro is absent", function()
    eq(nil, model.build(cfg, data, ident, ident, env).intro)
  end)
end)

describe("model collapsed state", function()
  local ccfg = {
    sections = {
      { title = "A", collapsed = true },
      { title = "B" },
      { title = "C", collapsed = false },
    },
    window = { footer = "f" },
  }
  local state = model.build(ccfg, { scanned = { {}, {}, {} }, live = {} }, ident, ident)

  it("build copies collapsed onto each section state (default false)", function()
    eq(
      { true, false, false },
      vim.tbl_map(function(s)
        return s.collapsed
      end, state.sections)
    )
  end)

  it("initial_view maps every section id to its collapsed flag", function()
    eq({ collapsed = { [1] = true, [2] = false, [3] = false } }, model.initial_view(state))
  end)

  local view = { collapsed = { [1] = true, [2] = false, [3] = false } }

  it("toggle flips one id", function()
    eq({ collapsed = { [1] = false, [2] = false, [3] = false } }, model.reduce(view, { type = "toggle", id = 1 }))
    eq({ collapsed = { [1] = true, [2] = true, [3] = false } }, model.reduce(view, { type = "toggle", id = 2 }))
  end)

  it("open and close set one id idempotently", function()
    eq({ collapsed = { [1] = false, [2] = false, [3] = false } }, model.reduce(view, { type = "open", id = 1 }))
    eq(view, model.reduce(view, { type = "open", id = 2 }))
    eq({ collapsed = { [1] = true, [2] = true, [3] = false } }, model.reduce(view, { type = "close", id = 2 }))
    eq(view, model.reduce(view, { type = "close", id = 1 }))
  end)

  it("open_all and close_all affect every id", function()
    eq({ collapsed = { [1] = false, [2] = false, [3] = false } }, model.reduce(view, { type = "open_all" }))
    eq({ collapsed = { [1] = true, [2] = true, [3] = true } }, model.reduce(view, { type = "close_all" }))
  end)

  it("reduce never mutates its input", function()
    local before = vim.deepcopy(view)
    for _, a in ipairs {
      { type = "toggle", id = 1 },
      { type = "open", id = 1 },
      { type = "close", id = 2 },
      { type = "open_all" },
      { type = "close_all" },
      { type = "bogus" },
    } do
      local new = model.reduce(view, a)
      ok(new ~= view, "returned the same table")
      eq(before, view)
    end
  end)

  it("unknown id or type returns an equal copy", function()
    for _, a in ipairs {
      { type = "toggle", id = 99 },
      { type = "open", id = 99 },
      { type = "close", id = 99 },
      { type = "nope" },
    } do
      local new = model.reduce(view, a)
      ok(new ~= view)
      eq(view, new)
    end
  end)
end)
