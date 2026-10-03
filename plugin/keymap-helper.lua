-- Defines :KeymapHelper and the default key at startup without loading the rest of the plugin.
-- Everything heavy is required inside the callbacks, so a lazy.nvim
-- `cmd = { "KeymapHelper" }` stub and this file agree on the same entry point.
if vim.g.loaded_keymap_helper then
  return
end
vim.g.loaded_keymap_helper = true

vim.api.nvim_create_user_command("KeymapHelper", function(args)
  require("keymap-helper.commands").dispatch(args.fargs, args.bang)
end, {
  nargs = "*",
  bang = true,
  desc = "keymap-helper",
  complete = function(arglead, cmdline, pos)
    return require("keymap-helper.commands").complete(arglead, cmdline, pos)
  end,
})

-- The default <leader>km. setup() moves or removes it (`keymap` option), and a
-- key the user already mapped is left alone.
require("keymap-helper.keymap").apply()
