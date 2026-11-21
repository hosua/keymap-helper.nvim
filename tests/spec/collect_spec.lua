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
    eq("<Space>zq", collect.command_key())
    vim.keymap.del("n", "<leader>zq")
  end)
end)
