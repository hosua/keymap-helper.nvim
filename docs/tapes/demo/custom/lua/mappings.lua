require "nvchad.mappings"

local map = vim.keymap.set

-- ┌──────────────────────────────────────────┐
-- │ General                                  │
-- └──────────────────────────────────────────┘

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>", { desc = "escape insert mode" })
map("n", "<C-s>", "<cmd>w<CR>", { desc = "save file" })
map("n", "<leader>h", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })

-- ┌──────────────────────────────────────────┐
-- │ Splits                                   │
-- └──────────────────────────────────────────┘

map("n", "<leader>-", "<cmd>vsp<CR>", { desc = "split vertically" })
map("n", "<leader>=", "<cmd>sp<CR>", { desc = "split horizontally" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "close current split" })

-- ┌──────────────────────────────────────────┐
-- │ Git / goto  (<leader>g)                  │
-- └──────────────────────────────────────────┘

map("n", "<leader>gg", "<cmd>LazyGit<CR>", { desc = "open lazygit TUI" })
map("n", "<leader>gb", "<cmd>Gitsigns blame<CR>", { desc = "blame current line" })
map("n", "<leader>gd", vim.lsp.buf.definition, { desc = "go to definition" })
map("n", "<leader>gr", vim.lsp.buf.references, { desc = "list references" })

-- ┌──────────────────────────────────────────┐
-- │ Telescope  (<leader>f)                   │
-- └──────────────────────────────────────────┘

map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "find files" })
map("n", "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "find open buffers" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "recent files" })
