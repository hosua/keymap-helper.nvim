-- Sections: filtered by an lhs pattern, plugin maps grouped by plugin, the rest grouped by <leader>x.
vim.opt.rtp:prepend(vim.env.KMH_REPO)
for _, p in ipairs { "telescope.nvim", "gitsigns.nvim" } do -- stand-ins for installed plugins
  vim.opt.rtp:append(vim.env.KMH_DEMO .. "/demo/plugins/" .. p)
end
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"

local map = vim.keymap.set
map("n", "<leader>ff", "<cmd>echo 1<cr>", { desc = "find files" })
map("n", "<leader>fg", "<cmd>echo 1<cr>", { desc = "live grep" })
map("n", "<leader>fb", "<cmd>echo 1<cr>", { desc = "find buffers" })
map("n", "<leader>gs", "<cmd>echo 1<cr>", { desc = "git status" })
map("n", "<leader>gb", "<cmd>echo 1<cr>", { desc = "git blame line" })
map("n", "<leader>gc", "<cmd>echo 1<cr>", { desc = "git commit" })
map("n", "<leader>w", "<cmd>w<cr>", { desc = "save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "quit window" })

require("keymap-helper").setup {
  sections = {
    { title = "Git", subtitle = "lhs = ^<leader>g", lhs = "^<leader>g" },
    { title = "Plugins", plugin = true, group_by = "plugin" },
    { title = "Everything else", config = true, group_by = "leader_prefix" },
  },
}
