require "nvchad.mappings"

local map = vim.keymap.set

-- Retired defaults.
vim.keymap.del("n", "<leader>v")
vim.keymap.del("n", "<leader>n")

map("n", "<leader>h", "<cmd>HelpGrep<CR>", { desc = "grep the help pages" })
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "live grep" })
map("n", "<leader>gb", "<cmd>Gitsigns blame_line<CR>", { desc = "git blame line" })
map("n", "<leader>gb", "<cmd>Git blame<CR>", { desc = "git blame file" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "toggle the file tree" })
map("n", "<leader>ln", "<cmd>set nu!<CR>", { desc = "toggle line number" })
