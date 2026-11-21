-- Fixture: the shape of a real NvChad-style lua/mappings.lua.
require "nvchad.mappings"

local map = vim.keymap.set

-- ┌──────────────────────────────┐
-- │ General                      │
-- └──────────────────────────────┘

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- ┌──────────────────────────────┐
-- │ Git  (<leader>g)             │
-- └──────────────────────────────┘

map({ "n", "x" }, "<leader>gb", function()
  local x = 1
  return x
end, { desc = "git blame line" })
map("n", "<leader>gd", function()
  print "no desc on this one"
end)
map("n", "<C-h>", "<C-w>h", { desc = "window left" })
vim.keymap.set("v", "<leader>gy", "<cmd>echo 1<cr>", {
  desc = "yank permalink",
})
