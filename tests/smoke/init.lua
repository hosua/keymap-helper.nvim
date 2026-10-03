-- Minimal config for tmux smoke tests: this checkout on the rtp, a leader,
-- a few mappings, and a section that scans the fixture file.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h:h")
vim.opt.runtimepath:prepend(root)
vim.cmd "runtime plugin/keymap-helper.lua"
vim.g.mapleader = " "

local map = vim.keymap.set
map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>km", "<cmd>KeymapHelper<cr>", { desc = "show keymaps" })
map({ "n", "x" }, "<leader>gb", "<cmd>echo 1<cr>", { desc = "git blame line" })
map("i", "jk", "<ESC>")
map("n", "<leader>zz", "<cmd>echo 'z'<cr>", { desc = "unclaimed smoke map" })

require("keymap-helper").setup {
  sections = {
    { title = "Custom", subtitle = "fixture", files = { root .. "/tests/fixtures/mappings.lua" }, group_by = "header" },
    { title = "Default", rest = true, collapsed = true },
  },
  hint = { timeout_ms = 60000 },
}
