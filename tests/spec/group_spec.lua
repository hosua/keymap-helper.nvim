local group = require "keymap-helper.group"

local function item(modes, lhs, desc, extra)
  return vim.tbl_extend("force", { modes = modes, lhs = lhs, desc = desc or "d" }, extra or {})
end

local function titles(groups)
  return vim.tbl_map(function(g)
    return g.title
  end, groups)
end

describe("group.mode_list", function()
  it("sorts by mode order and dedupes", function()
    eq("n,x", group.mode_list { "x", "n" })
    eq("n,i,t", group.mode_list { "t", "i", "n", "n" })
    eq("n,z", group.mode_list { "z", "n" })
  end)
end)

describe("group.leader_prefix", function()
  it("derives the prefix token", function()
    eq("<leader>g", group.leader_prefix "<leader>gb")
    eq("<leader>", group.leader_prefix "<leader>q")
    eq("<leader><C-x>", group.leader_prefix "<leader><C-x>a")
    eq("<leader>", group.leader_prefix "<leader><C-x>")
    eq(nil, group.leader_prefix "K")
    eq(nil, group.leader_prefix "<leader>")
  end)
end)

describe("group.merge", function()
  it("merges same lhs and desc across modes", function()
    local out = group.merge { item({ "n" }, "<leader>a", "x"), item({ "x" }, "<leader>a", "x") }
    eq(1, #out)
    eq("n,x", group.mode_list(out[1].modes))
  end)

  it("keeps different descs apart", function()
    eq(2, #group.merge { item({ "n" }, "<leader>a", "x"), item({ "x" }, "<leader>a", "y") })
  end)

  it("takes the smallest order and does not mutate", function()
    local a, b = item({ "n" }, "k", "x", { order = 5 }), item({ "x" }, "k", "x", { order = 2 })
    local out = group.merge { a, b }
    eq(2, out[1].order)
    eq(5, a.order)
    eq({ "n" }, a.modes)
  end)
end)

describe("group.build", function()
  it("none: one untitled group sorted by order then lhs", function()
    local out = group.build({
      item({ "n" }, "b", "d"),
      item({ "n" }, "a", "d"),
      item({ "n" }, "z", "d", { order = 1 }),
    }, "none", {})
    eq(1, #out)
    eq(nil, out[1].title)
    eq(
      { "z", "a", "b" },
      vim.tbl_map(function(r)
        return r.lhs
      end, out[1].rows)
    )
    eq({ modes = "n", lhs = "z", desc = "d" }, out[1].rows[1])
  end)

  it("none: empty gives no groups", function()
    eq({}, group.build({}, "none", {}))
  end)

  it("header: groups ordered by smallest order, ungrouped appended by prefix", function()
    local out = group.build({
      item({ "n" }, "<leader>b", "d", { group = "B", order = 5 }),
      item({ "n" }, "<leader>a", "d", { group = "A", order = 1 }),
      item({ "n" }, "<leader>q", "d"),
    }, "header", {})
    eq({ "A", "B", "<leader>" }, titles(out))
  end)

  it("plugin: titles by plugin name, Other for none, sorted case-insensitively", function()
    local out = group.build({
      item({ "n" }, "a", "d", { plugin = "telescope.nvim" }),
      item({ "n" }, "b", "d", { plugin = "NvChad" }),
      item({ "n" }, "c", "d"),
    }, "plugin", {})
    eq({ "NvChad", "Other", "telescope.nvim" }, titles(out))
  end)

  it("leader_prefix: singleton, which-key names, Other keys", function()
    local out = group.build({
      item({ "n" }, "<leader>gs"),
      item({ "n" }, "<leader>gb"),
      item({ "n" }, "<leader>q"),
      item({ "n" }, "K"),
    }, "leader_prefix", { ["<leader>g"] = "git" })
    eq({ "<leader>", "<leader>g  git", "Other keys" }, titles(out))
    eq("<leader>gb", out[2].rows[1].lhs)
    eq("<leader>gs", out[2].rows[2].lhs)
  end)
end)
