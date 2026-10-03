--- keymap-helper: public API.
---
--- setup() is optional: every entry point resolves the config on first use,
--- so the plugin works with `opts = {}` or with no setup call at all.
local M = {}

local config = require "keymap-helper.config"

--- @param opts table|nil user overrides, merged over config.defaults
function M.setup(opts)
  local cfg = config.resolve(opts)
  require("keymap-helper.keymap").apply(cfg.keymap)
  if not cfg.hint.enabled then
    return
  end
  -- Loaded on VimEnter (lazy `event`) or later: show it now. Loaded at
  -- startup: wait for VimEnter so the hint lands on the final layout.
  if vim.v.vim_did_enter == 1 then
    vim.schedule(M.hint)
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("KeymapHelperHint", { clear = true }),
      once = true,
      callback = function()
        vim.schedule(M.hint)
      end,
    })
  end
end

--- Start recording which file calls vim.keymap.set (opt-in). Call it from the
--- first lines of init.lua, before plugins cache `vim.keymap.set`.
--- @return boolean installed true when the wrapper is active
function M.track()
  return require("keymap-helper.track").install()
end

--- Open the grouped keymap list.
--- @return integer win
function M.show()
  local cfg = config.get()
  local collect = require "keymap-helper.collect"
  local model = require "keymap-helper.model"
  require("keymap-helper.highlights").apply()
  local env = { mapleader = vim.g.mapleader, maplocalleader = vim.g.maplocalleader }
  local state = model.build(cfg, model.gather(cfg), collect.normalize, collect.display, env)
  return (
    require("keymap-helper.ui.float").open_list(
      state,
      model.initial_view(state),
      { title = cfg.window.title, max_width = cfg.window.max_width }
    )
  )
end

--- Show the startup nudge toward the list. The key shown is whatever the
--- user mapped to :KeymapHelper, so the hint stays true after a remap.
--- @return integer win
function M.hint()
  local cfg = config.get()
  require("keymap-helper.highlights").apply()
  local key = require("keymap-helper.collect").command_key() or ":KeymapHelper"
  local text = (cfg.hint.message:gsub("{key}", function()
    return key
  end))
  return require("keymap-helper.ui.float").toast(
    { text },
    { timeout_ms = cfg.hint.timeout_ms, position = cfg.hint.position }
  )
end

return M
