-- Defines :KeymapHelper at startup without loading the plugin's Lua modules.
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
