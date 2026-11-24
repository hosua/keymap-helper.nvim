-- Demo config for the conflict screenshots: a tiny stand-in for NvChad (its
-- defaults file on the runtimepath) plus this plugin from $KMH_REPO.
local repo = vim.env.KMH_REPO
vim.opt.runtimepath:prepend(repo)
dofile(repo .. "/tests/deps.lua").setup(repo)
vim.g.mapleader = " "
vim.opt.runtimepath:append(vim.fn.stdpath "config" .. "/fake-nvchad")
vim.cmd "runtime plugin/keymap-helper.lua"
require("keymap-helper").setup {
  sections = {
    { title = "NvChad defaults", runtime_files = { "lua/nvchad/mappings.lua" }, collapsed = true },
    { title = "Default", rest = true },
  },
  hint = { enabled = false },
}
vim.schedule(function()
  require "mappings"
end)
