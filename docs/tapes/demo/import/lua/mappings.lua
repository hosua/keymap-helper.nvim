local map = vim.keymap.set

map("n", ";", ":", { desc = "enter command mode" })
map("n", "<leader>w", "<cmd>w<cr>", { desc = "save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "quit window" })
map("i", "jk", "<Esc>", { desc = "leave insert mode" })
