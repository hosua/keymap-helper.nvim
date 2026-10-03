-- One-line config: only NvChad's maps are split out, folded. Everything else lands in "Default".
vim.opt.rtp:prepend(vim.env.KMH_REPO)
vim.opt.rtp:append(vim.env.KMH_DEMO .. "/demo/nvchad") -- stands in for an NvChad install
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"

require "nvchad.mappings"
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "save file" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "quit window" })

require("keymap-helper").setup {
  sections = { { title = "NvChad defaults", runtime_files = { "lua/nvchad/mappings.lua" }, collapsed = true } },
}
