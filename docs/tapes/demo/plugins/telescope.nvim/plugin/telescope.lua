-- Stand-in for a plugin: Lua-callback maps, so the list can name the plugin by its rtp directory.
vim.keymap.set("n", "<C-p>", function() end, { desc = "telescope: find files" })
vim.keymap.set("n", "<C-g>", function() end, { desc = "telescope: live grep" })
