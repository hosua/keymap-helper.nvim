-- The README's NvChad example: custom maps (grouped by header) first, NvChad's own folded.
vim.opt.rtp:prepend(vim.env.KMH_REPO)
vim.opt.rtp:append(vim.env.KMH_DEMO .. "/demo/nvchad") -- stands in for an NvChad install
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"

if vim.env.KMH_TRACK == "1" then
  require("keymap-helper").track() -- opt-in: records the file of every vim.keymap.set
end
require "mappings"

require("keymap-helper").setup {
  sections = {
    { title = "Custom", subtitle = "lua/mappings.lua", files = { "lua/mappings.lua" }, group_by = "header" },
    { title = "NvChad defaults", runtime_files = { "lua/nvchad/mappings.lua" }, collapsed = true },
  },
}
