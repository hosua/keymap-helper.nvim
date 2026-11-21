-- show_undocumented = true: maps with no desc are listed too (blank description).
vim.opt.rtp:prepend(vim.env.KMH_REPO)
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"

local map = vim.keymap.set
map("n", "<leader>w", "<cmd>w<cr>", { desc = "save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "quit window" })
map("i", "jk", "<Esc>")
map("n", "<leader>bd", "<cmd>bdelete<cr>")
map("n", "<Plug>(demo-action)", "<cmd>echo 1<cr>")

require("keymap-helper").setup {
  show_undocumented = true,
  sections = { { title = "Config", config = true } },
}
