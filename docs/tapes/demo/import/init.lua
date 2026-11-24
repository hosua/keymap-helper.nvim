-- Template demo: a hand-written lua/mappings.lua next to a template that no longer
-- matches it, so :KeymapHelper import asks before replacing the template.
vim.opt.rtp:prepend(vim.env.KMH_REPO)
dofile(vim.env.KMH_REPO .. "/tests/deps.lua").setup(vim.env.KMH_REPO)
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"
require("keymap-helper").setup {}
