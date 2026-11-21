--- :checkhealth keymap-helper
local M = {}

function M.check()
  local h = vim.health
  h.start "keymap-helper"
  if vim.fn.has "nvim-0.11" == 1 then
    h.ok("Neovim " .. tostring(vim.version()))
  else
    h.error "Neovim >= 0.11 is required"
  end
  -- Which copy is loaded matters when a dev checkout and a lazy clone coexist.
  local src = debug.getinfo(require("keymap-helper").setup, "S").source:gsub("^@", "")
  h.info("loaded from " .. vim.fn.fnamemodify(src, ":~"))

  h.start "keymap-helper: sections"
  local cfg = require("keymap-helper.config").get()
  local model = require "keymap-helper.model"
  for _, s in ipairs(cfg.sections) do
    if s.rest then
      h.ok(("%s: every unclaimed mapping with a description"):format(s.title))
    elseif not s.files and not s.runtime_files then
      h.warn(("%s: no files and not `rest`, so it will always be empty"):format(s.title))
    else
      local paths = model.section_paths(s)
      if #paths == 0 then
        h.warn(("%s: none of its files were found"):format(s.title), {
          "relative `files` resolve against " .. vim.fn.stdpath "config",
          "`runtime_files` are looked up on 'runtimepath'",
        })
      else
        for _, p in ipairs(paths) do
          h.ok(("%s: %s"):format(s.title, vim.fn.fnamemodify(p, ":~")))
        end
      end
    end
  end
end

return M
