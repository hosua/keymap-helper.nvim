-- hint.position = "bottom_right" and a custom message; {key} is whatever opens the list.
vim.opt.rtp:prepend(vim.env.KMH_REPO)
vim.g.mapleader = " "
vim.cmd.colorscheme "habamax"

require("keymap-helper").setup {
  hint = { position = "bottom_right", message = "Press {key} for your keymaps", timeout_ms = 8000 },
}
