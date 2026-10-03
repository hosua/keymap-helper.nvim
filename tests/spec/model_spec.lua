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

local C = { kind = "config", via = "callback" }

local auto_cfg = {
  sections = {
    { title = "Custom", files = { "x" }, group_by = "header" },
    { title = "Hidden", lhs = "^<leader>h", hidden = true },
    { title = "Your config", config = true, group_by = "header" },
    { title = "Plugins", plugin = true, group_by = "plugin", collapsed = true },
    { title = "Defaults", builtin = true },
    { title = "Default", rest = true, collapsed = true },
  },
  window = { footer = "q to close" },
}

local auto_data = {
  scanned = {
    {
      { group = "General", modes = "n", lhs = ";", desc = "CMD" },
      { group = "General", modes = "i", lhs = "jk", desc = "" },
      { group = "Git", modes = "n,x", lhs = "<leader>gb", desc = "" },
      { group = "Git", modes = "n", lhs = "<leader>v", desc = "deleted" },
    },
  },
  live = {
    { mode = "n", lhs = ";", desc = "CMD", origin = C },
    { mode = "i", lhs = "jk", origin = C },
    { mode = "x", lhs = "<leader>gb", desc = "blame", origin = C },
    { mode = "n", lhs = "<leader>gb", desc = "blame", origin = C },
    {
      mode = "n",
      lhs = "<leader>ln",
      desc = "line nr",
      origin = { kind = "config", via = "index", group = "Lines", order = 7 },
    },
    { mode = "n", lhs = "<leader>q", desc = "quit", origin = C },
    {
      mode = "n",
      lhs = "<leader>ff",
      desc = "find",
      origin = { kind = "plugin", plugin = "telescope.nvim", via = "lazy_keys" },
    },
    {
      mode = "n",
      lhs = "<C-s>",
      desc = "save",
      origin = { kind = "plugin", plugin = "NvChad", via = "callback" },
    },
    { mode = "n", lhs = "Y", desc = ":help Y-default", origin = { kind = "builtin", via = "heuristic" } },
    { mode = "n", lhs = "<leader>hx", desc = "secret", origin = C },
    { mode = "n", lhs = "zz", origin = { kind = "unknown", via = "none" } },
    { mode = "n", lhs = "<Plug>(foo)", desc = "plug", origin = { kind = "unknown", via = "none" } },
    { mode = "n", lhs = "gx", desc = "open" },
  },
}

local function sec(state, id)
  for _, s in ipairs(state.sections) do
    if s.id == id then
      return s
    end
  end
end

local function lhs_of(section)
  local out = {}
  for _, g in ipairs(section.groups) do
    for _, r in ipairs(g.rows) do
      table.insert(out, r.lhs)
    end
  end
  return out
end

describe("model.build", function()
  local state = model.build(auto_cfg, auto_data, ident, ident)

  it("keeps section ids and drops hidden sections", function()
    eq(
      { 1, 3, 4, 5, 6 },
      vim.tbl_map(function(s)
        return s.id
      end, state.sections)
    )
    eq("q to close", state.footer)
  end)

  it("file sections show live maps (even without desc) grouped by header", function()
    local custom = sec(state, 1)
    eq({ "General", "Git" }, { custom.groups[1].title, custom.groups[2].title })
    eq({
      { modes = "n", lhs = ";", desc = "CMD" },
      { modes = "i", lhs = "jk", desc = "" },
    }, custom.groups[1].rows)
    eq({ { modes = "n,x", lhs = "<leader>gb", desc = "blame" } }, custom.groups[2].rows)
    eq(3, custom.count)
  end)

  it("maps deleted from the live set (<leader>v) do not appear", function()
    for _, s in ipairs(state.sections) do
      for _, l in ipairs(lhs_of(s)) do
        ok(l ~= "<leader>v", "found <leader>v in " .. s.title)
      end
    end
  end)

  it("hidden sections claim maps without being shown", function()
    for _, s in ipairs(state.sections) do
      for _, l in ipairs(lhs_of(s)) do
        ok(l ~= "<leader>hx", "found <leader>hx in " .. s.title)
      end
    end
  end)

  it("config section: index group first, then leader_prefix groups", function()
    local cfgs = sec(state, 3)
    eq({ "Lines", "<leader>" }, { cfgs.groups[1].title, cfgs.groups[2].title })
    eq({ { modes = "n", lhs = "<leader>ln", desc = "line nr" } }, cfgs.groups[1].rows)
    eq({ { modes = "n", lhs = "<leader>q", desc = "quit" } }, cfgs.groups[2].rows)
  end)

  it("plugin section groups by plugin name, case-insensitively sorted", function()
    local plugins = sec(state, 4)
    eq({ "NvChad", "telescope.nvim" }, { plugins.groups[1].title, plugins.groups[2].title })
    eq("<C-s>", plugins.groups[1].rows[1].lhs)
    eq("<leader>ff", plugins.groups[2].rows[1].lhs)
    eq(true, plugins.collapsed)
  end)

  it("builtin section is one untitled group", function()
    eq({ { rows = { { modes = "n", lhs = "Y", desc = ":help Y-default" } } } }, sec(state, 5).groups)
  end)

  it("rest section gets only unclaimed documented maps", function()
    eq({ { rows = { { modes = "n", lhs = "gx", desc = "open" } } } }, sec(state, 6).groups)
  end)

  it("show_undocumented adds undocumented and <Plug> maps to rest", function()
    local shown = model.build(vim.tbl_extend("force", auto_cfg, { show_undocumented = true }), auto_data, ident, ident)
    eq({ "<Plug>(foo)", "gx", "zz" }, lhs_of(sec(shown, 6)))
  end)

  it("evaluates rest sections after all others", function()
    local c = {
      sections = { { title = "All", rest = true }, { title = "Mine", config = true } },
      window = {},
    }
    local d = {
      scanned = { {}, {} },
      live = {
        { mode = "n", lhs = "a", desc = "mine", origin = C },
        { mode = "n", lhs = "b", desc = "other", origin = { kind = "unknown", via = "none" } },
      },
    }
    local s = model.build(c, d, ident, ident)
    eq({ "a" }, lhs_of(sec(s, 2)))
    eq({ "b" }, lhs_of(sec(s, 1)))
  end)

  it("appends an implicit collapsed Default only when it has rows", function()
    local c = { sections = { { title = "Mine", config = true } }, window = {} }
    local live = {
      { mode = "n", lhs = "a", desc = "mine", origin = C },
      { mode = "n", lhs = "b", desc = "other", origin = { kind = "unknown", via = "none" } },
    }
    local s = model.build(c, { scanned = { {} }, live = live }, ident, ident)
    eq(2, #s.sections)
    eq(2, s.sections[2].id)
    eq("Default", s.sections[2].title)
    eq("everything else with a description", s.sections[2].subtitle)
    eq(true, s.sections[2].collapsed)
    eq({ "b" }, lhs_of(s.sections[2]))

    local only = model.build(c, { scanned = { {} }, live = { live[1] } }, ident, ident)
    eq(1, #only.sections)
  end)

  it("the implicit Default section is open when the user has no sections", function()
    local live = { { mode = "n", lhs = "b", desc = "other", origin = { kind = "unknown", via = "none" } } }
    local s = model.build({ sections = {}, window = {} }, { scanned = {}, live = live }, ident, ident)
    eq(1, #s.sections)
    eq("Default", s.sections[1].title)
    eq(false, s.sections[1].collapsed)
    eq({ "b" }, lhs_of(s.sections[1]))
  end)

  it("a file section with an entry that is not live has count 0", function()
    local s = model.build(
      { sections = { { title = "F", files = { "x" } } }, window = {} },
      { scanned = { { { group = "G", modes = "n", lhs = "gone", desc = "d" } } }, live = {} },
      ident,
      ident
    )
    eq(0, s.sections[1].count)
    eq({}, s.sections[1].groups)
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
