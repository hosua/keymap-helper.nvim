local collect = require "keymap-helper.collect"

describe("collect.normalize", function()
  it("gives file spelling and nvim's report the same key", function()
    vim.g.mapleader = " "
    eq(collect.normalize "<C-h>", collect.normalize "<c-H>")
    eq(collect.normalize "<leader>ff", collect.normalize " ff")
  end)
end)

describe("collect.display", function()
  it("shows the leader as <leader>", function()
    vim.g.mapleader = " "
    eq("<leader>ff", collect.display " ff")
    eq("<C-H>", collect.display "<C-h>")
  end)

  it("handles the default backslash leader", function()
    vim.g.mapleader = nil
    eq("<leader>x", collect.display "\\x")
    vim.g.mapleader = " "
  end)
end)

describe("collect.live / command_key", function()
  it("reports global maps with canonical lhs and finds the :KeymapHelper key", function()
    vim.g.mapleader = " "
    vim.keymap.set("n", "<leader>zq", "<cmd>KeymapHelper<cr>", { desc = "km test" })
    local found
    for _, m in ipairs(collect.live { "n" }) do
      if m.desc == "km test" then
        found = m
      end
    end
    ok(found, "mapping not reported")
    eq("<Space>zq", found.lhs)
    eq("<leader>zq", collect.command_key())
    vim.keymap.del("n", "<leader>zq")
  end)
end)

describe("collect.own_mode", function()
  local want = { n = true, v = true, x = true, i = true, t = true }

  it("maps a returned map's mode to its own mode", function()
    eq("n", collect.own_mode("n", "n", want))
    eq("n", collect.own_mode(" ", "n", want))
    eq("v", collect.own_mode("v", "x", want))
    eq("x", collect.own_mode("x", "v", want))
    eq(nil, collect.own_mode("s", "v", want))
    eq("i", collect.own_mode("!", "i", want))
    eq("x", collect.own_mode("v", "x", { x = true }))
  end)
end)

describe("collect.live own modes", function()
  it("reports an x-only map once, with mode x", function()
    vim.g.mapleader = " "
    vim.keymap.set("x", "<leader>zx", "<cmd>echo 1<cr>", { desc = "x only" })
    local hits = {}
    for _, m in ipairs(collect.live { "v", "x" }) do
      if m.desc == "x only" then
        table.insert(hits, m.mode)
      end
    end
    pcall(vim.keymap.del, "x", "<leader>zx")
    eq({ "x" }, hits)
  end)
end)

describe("collect.own_mode partial masks", function()
  it("keeps maps whose mode is a partial mask such as nox or nv", function()
    local want = { n = true, v = true, x = true }
    eq("n", collect.own_mode("nox", "n", want))
    eq("x", collect.own_mode("nox", "x", want))
    eq("n", collect.own_mode("nv", "n", want))
  end)
end)
