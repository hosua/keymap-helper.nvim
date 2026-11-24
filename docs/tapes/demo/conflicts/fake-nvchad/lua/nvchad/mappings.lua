local map = vim.keymap.set

map("n", "<leader>h", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })
map("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "vertical split" })
map("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "toggle line number" })
map("n", "<leader>w", "<cmd>w<CR>", { desc = "write file" })
map("n", "<C-s>", "<cmd>w<CR>", { desc = "save file" })
