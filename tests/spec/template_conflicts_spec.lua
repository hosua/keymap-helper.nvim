local conflicts = require "keymap-helper.template.conflicts"

local function set(mode, lhs, source, desc, extra)
  return vim.tbl_extend("force", { op = "set", mode = mode, lhs = lhs, source = source, desc = desc }, extra or {})
end

local function del(mode, lhs, source)
  return { op = "del", mode = mode, lhs = lhs, source = source }
end

local function only(res)
  eq(1, #res.keys)
  return res.keys[1]
end

describe("conflicts: modes", function()
  it("expands lists, v, empty and ! into concrete modes", function()
    eq({ "n", "x" }, conflicts.modes { "n", "x" })
    eq({ "n" }, conflicts.modes "n")
    eq({ "x", "s" }, conflicts.modes "v")
    eq({ "n", "x", "s", "o" }, conflicts.modes "")
    eq({ "i", "c" }, conflicts.modes "!")
    eq({ "n", "x" }, conflicts.modes { "n", "x", "n" })
  end)
end)

describe("conflicts: build", function()
  it("reports nothing for keys defined once", function()
    local res = conflicts.build {
      set("n", "<Space>a", "default:nvchad"),
      set("n", "<Space>b", "template:e1"),
    }
    eq({}, res.keys)
    eq({ duplicates = 0, overrides = 0, removed = 0 }, res.counts)
  end)

  it("flags two template entries on one key as a duplicate, the later one wins", function()
    local res = conflicts.build {
      set("n", "<Space>x", "template:e1", "first"),
      set("n", "<Space>x", "template:e2", "second"),
    }
    local k = only(res)
    ok(k.duplicate)
    ok(not k.override)
    eq("template:e1", k.defs[1].source)
    eq("template:e2", k.defs[2].source)
    eq("template:e2", k.defs[1].shadowed_by)
    ok(k.defs[2].wins)
    ok(not k.defs[1].wins)
    eq(1, res.counts.duplicates)
  end)

  it("flags a template entry over a default as an override, not a duplicate", function()
    local res = conflicts.build {
      set("n", "<Space>h", "default:nvchad", "terminal new horizontal term", { summary = "new term" }),
      set("n", "<Space>h", "template:e7", "telescope help page"),
    }
    local k = only(res)
    ok(k.override)
    ok(not k.duplicate)
    eq("default:nvchad", k.defs[1].source)
    eq("new term", k.defs[1].summary)
    ok(k.defs[2].wins)
    eq(1, res.counts.overrides)
    eq(0, res.counts.duplicates)
  end)

  it("flags both when a duplicate also sits over a default", function()
    local k = only(conflicts.build {
      set("n", "a", "default:nvchad"),
      set("n", "a", "template:e1"),
      set("n", "a", "template:e2"),
    })
    ok(k.duplicate and k.override)
  end)

  it("does not call a delete-then-bind an override and keeps the deleted default", function()
    local res = conflicts.build {
      set("n", "<Space>v", "default:nvchad", "vertical terminal"),
      del("n", "<Space>v", "template:raw"),
      set("n", "<Space>v", "template:e3", "mine"),
    }
    local k = only(res)
    ok(not k.override)
    ok(not k.duplicate)
    eq(1, #k.defs)
    eq("template:e3", k.defs[1].source)
    eq(1, #k.removed)
    eq("default:nvchad", k.removed[1].source)
    eq("template:raw", k.removed[1].by)
    eq(1, res.counts.removed)
  end)

  it("reports a deleted default that nothing rebinds", function()
    local k = only(conflicts.build { set("n", "<Space>n", "default:nvchad"), del("n", "<Space>n", "template:raw") })
    eq({}, k.defs)
    eq(1, #k.removed)
  end)

  it("ignores buffer-local events", function()
    local res = conflicts.build {
      set("n", "gd", "plugin:lsp", "x", { buffer = true }),
      set("n", "gd", "template:e1", "y"),
    }
    eq({}, res.keys)
  end)

  it("keeps the same lhs in different modes apart", function()
    local res = conflicts.build {
      set("n", "<Space>q", "default:nvchad"),
      set("x", "<Space>q", "template:e1"),
    }
    eq({}, res.keys)
  end)

  it("treats the modes of a list as separate keys", function()
    local events = {}
    for _, m in ipairs(conflicts.modes { "n", "x" }) do
      events[#events + 1] = set(m, "<Space>q", "default:nvchad")
    end
    for _, m in ipairs(conflicts.modes { "n", "x" }) do
      events[#events + 1] = set(m, "<Space>q", "template:e1")
    end
    local res = conflicts.build(events)
    eq(2, #res.keys)
    eq(2, res.counts.overrides)
  end)

  it("counts a plugin map set before the template as an override too", function()
    local k = only(conflicts.build { set("n", "s", "plugin:leap"), set("n", "s", "template:e1") })
    ok(k.override)
  end)
end)

describe("live snapshot", function()
  it("lists the defaults of a runtime_files section and flags the ones no longer mapped", function()
    local live = require "keymap-helper.template.live"
    local dir = tmpdir()
    vim.fn.mkdir(dir .. "/lua/fakedefaults", "p")
    vim.fn.writefile({
      'map("n", "<C-F9>", "<cmd>One<CR>", { desc = "first default" })',
      'map("n", "<C-F10>", "<cmd>Two<CR>", { desc = "second default" })',
    }, dir .. "/lua/fakedefaults/mappings.lua")
    vim.opt.runtimepath:append(dir)
    vim.keymap.set("n", "<C-F9>", "<Nop>", { desc = "template one" })
    local cfg = vim.deepcopy(require("keymap-helper.config").get())
    cfg.sections = { { title = "Defaults", runtime_files = { "lua/fakedefaults/mappings.lua" } } }
    local snap = live.snapshot(cfg)
    vim.keymap.del("n", "<C-F9>")
    eq("static", snap.source)
    eq(1, snap.counts.removed)
    local by = {}
    for _, k in ipairs(snap.keys) do
      by[k.lhs] = k
    end
    eq("first default", by["<C-F9>"].defs[1].desc)
    eq("default:fakedefaults", by["<C-F9>"].defs[1].source)
    eq({}, by["<C-F10>"].defs)
    eq("second default", by["<C-F10>"].removed[1].desc)
  end)
end)
