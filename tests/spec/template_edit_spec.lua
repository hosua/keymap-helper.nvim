local edit = require "keymap-helper.template.edit"
local template = require "keymap-helper.template"
local schema = require "keymap-helper.template.schema"
local json = require "keymap-helper.template.json"

local function sample()
  local t = schema.new "lua/mappings.lua"
  t.categories[#t.categories + 1] = { id = "nav", title = "Navigation", subtitle = "moving around" }
  t.entries = {
    { id = "e1", kind = "map", category = "uncategorized", modes = { "n" }, lhs = "a", rhs = "x", _note = "keep" },
    { id = "e2", kind = "raw", category = "uncategorized", text = "local y = 1" },
    { id = "e3", kind = "map", category = "nav", modes = { "n", "v" }, lhs = "b", lua = "function() end" },
  }
  return t
end

local function plan(extra)
  return vim.tbl_extend("force", {
    categories = { { id = "uncategorized", title = "Uncategorized" }, { id = "nav", title = "Navigation" } },
    order = {
      { id = "e1", category = "uncategorized" },
      { id = "e2", category = "uncategorized" },
      { id = "e3", category = "nav" },
    },
  }, extra or {})
end

describe("template edit: view", function()
  it("gives the Lua line of every map and none for raw entries", function()
    local v = edit.view(sample())
    eq('map("n", "a", "x")', v.calls.e1)
    eq(nil, v.calls.e2)
    ok(v.calls.e3:find("function() end", 1, true))
  end)
end)

describe("template edit: apply_plan", function()
  it("moves and reorders entries and keeps unknown fields", function()
    local p = plan {
      order = {
        { id = "e3", category = "nav" },
        { id = "e1", category = "nav" },
        { id = "e2", category = "uncategorized" },
      },
    }
    local out = assert(edit.apply_plan(sample(), p))
    eq(
      { "e3", "e1", "e2" },
      vim.tbl_map(function(e)
        return e.id
      end, out.entries)
    )
    eq("nav", out.entries[2].category)
    eq("keep", out.entries[2]._note)
  end)

  it("drops the map entries named in `delete`", function()
    local p = plan { delete = { "e3" } }
    table.remove(p.order, 3)
    local out = assert(edit.apply_plan(sample(), p))
    eq(
      { "e1", "e2" },
      vim.tbl_map(function(e)
        return e.id
      end, out.entries)
    )
  end)

  it("refuses to delete raw entries, unknown ids, or an entry it also places", function()
    local p = plan { delete = { "e2" } }
    table.remove(p.order, 2)
    local _, err = edit.apply_plan(sample(), p)
    ok(err:find("raw Lua", 1, true), err)
    _, err = edit.apply_plan(sample(), plan { delete = { "nope" } })
    ok(err:find("not in the template", 1, true), err)
    _, err = edit.apply_plan(sample(), plan { delete = { "e3" } })
    ok(err:find("both deleted and placed", 1, true), err)
  end)

  it("renames a category and keeps its subtitle", function()
    local p = plan()
    p.categories[2].title = "Moving"
    local out = assert(edit.apply_plan(sample(), p))
    eq("Moving", out.categories[2].title)
    eq("moving around", out.categories[2].subtitle)
  end)

  it("gives a new category a slug id, and a free one when the slug is taken", function()
    local p = plan()
    p.categories[#p.categories + 1] = { id = "new:1", title = "Navigation", new = true }
    p.categories[#p.categories + 1] = { id = "new:2", title = "LSP / Diagnostics", new = true }
    p.order[1].category = "new:1"
    p.order[2].category = "new:2"
    local out = assert(edit.apply_plan(sample(), p))
    eq("navigation", out.categories[3].id)
    eq("lsp-diagnostics", out.categories[4].id)
    eq("navigation", out.entries[1].category)
    eq("lsp-diagnostics", out.entries[2].category)
  end)

  it("lets a new category reuse the id of one that was deleted", function()
    local p = {
      categories = {
        { id = "uncategorized", title = "Uncategorized" },
        { id = "n2", title = "Navigation", new = true },
      },
      order = {
        { id = "e1", category = "n2" },
        { id = "e2", category = "uncategorized" },
        { id = "e3", category = "uncategorized" },
      },
    }
    local out = assert(edit.apply_plan(sample(), p))
    eq("navigation", out.categories[2].id)
  end)

  it("refuses a plan that drops, repeats or invents an entry or a category", function()
    local p = plan()
    table.remove(p.order)
    ok(select(2, edit.apply_plan(sample(), p)):find("leaves out entry e3", 1, true))
    p = plan()
    p.order[3] = { id = "e1", category = "nav" }
    ok(select(2, edit.apply_plan(sample(), p)):find("twice", 1, true))
    p = plan()
    p.order[3] = { id = "zzz", category = "nav" }
    ok(select(2, edit.apply_plan(sample(), p)):find("not in the template", 1, true))
    p = plan()
    p.order[1].category = "ghost"
    ok(select(2, edit.apply_plan(sample(), p)):find("not in the plan", 1, true))
    p = plan()
    p.categories[1] = { id = "nav", title = "x" }
    ok(select(2, edit.apply_plan(sample(), p)))
    p = plan()
    table.remove(p.categories, 1)
    ok(select(2, edit.apply_plan(sample(), p)):find("uncategorized", 1, true))
  end)

  it("does not change the template it was given", function()
    local t = sample()
    local before = vim.deepcopy(t)
    assert(edit.apply_plan(
      t,
      plan {
        order = {
          { id = "e3", category = "uncategorized" },
          { id = "e1", category = "nav" },
          { id = "e2", category = "nav" },
        },
      }
    ))
    eq(before, t)
  end)
end)

describe("template edit: show, preview and save_plan", function()
  local function root_with_template()
    local root = tmpdir()
    vim.fn.mkdir(root .. "/lua", "p")
    vim.fn.writefile(vim.split(json.encode(sample()), "\n"), root .. "/lua/mappings.template.json")
    return root
  end

  it("show says missing, then ready", function()
    local root = tmpdir()
    vim.fn.mkdir(root .. "/lua", "p")
    local v = assert(template.show { root = root })
    eq("missing", v.status)
    eq(false, v.source_exists)
    vim.fn.writefile({ 'map("n", "a", "b")' }, root .. "/lua/mappings.lua")
    eq(true, assert(template.show { root = root }).source_exists)
    root = root_with_template()
    v = assert(template.show { root = root })
    eq("ready", v.status)
    eq(3, #v.entries)
  end)

  it("save_plan writes the template and backs up the old one", function()
    local root = root_with_template()
    local res = assert(template.save_plan(
      plan {
        order = {
          { id = "e3", category = "nav" },
          { id = "e1", category = "nav" },
          { id = "e2", category = "uncategorized" },
        },
      },
      { root = root, now = 1000000000 }
    ))
    ok(res.backup and res.backup:match "mappings%.template_%d+_%d+_%d+_%d+:%d+:%d+%.bak$")
    local v = assert(template.show { root = root })
    eq("e3", v.entries[1].id)
  end)

  it("save_plan leaves the file alone when the plan is bad", function()
    local root = root_with_template()
    local before = vim.fn.readfile(root .. "/lua/mappings.template.json")
    local res, err = template.save_plan({ categories = {}, order = {} }, { root = root })
    eq(nil, res)
    ok(err)
    eq(before, vim.fn.readfile(root .. "/lua/mappings.template.json"))
    eq(0, #vim.fn.glob(root .. "/lua/*.bak", false, true))
  end)

  it("preview builds from the mappings file and writes nothing", function()
    local root = tmpdir()
    vim.fn.mkdir(root .. "/lua", "p")
    vim.fn.writefile({
      "-- ┌" .. ("─"):rep(10) .. "┐",
      "-- │ Nav │",
      "-- └" .. ("─"):rep(10) .. "┘",
      'map("n", "a", "b")',
    }, root .. "/lua/mappings.lua")
    local v = assert(template.preview { root = root, keep_headers = true })
    eq("preview", v.status)
    eq(1, #v.entries)
    eq(false, vim.uv.fs_stat(root .. "/lua/mappings.template.json") ~= nil)
  end)
end)
