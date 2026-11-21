-- Zero-config demo: setup {} and a few maps. <leader>km comes from the plugin itself.
vim.opt.rtp:prepend(vim.env.KMH_REPO)
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"

local map = vim.keymap.set
map("n", ";", ":", { desc = "enter command mode" })
map("n", "<leader>w", "<cmd>w<cr>", { desc = "save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "quit window" })
map("n", "<leader>e", "<cmd>Explore<cr>", { desc = "open file explorer" })
map({ "n", "x" }, "<leader>y", '"+y', { desc = "copy to system clipboard" })
map("i", "jk", "<Esc>", { desc = "leave insert mode" })

require("keymap-helper").setup {}
