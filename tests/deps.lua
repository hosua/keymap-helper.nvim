-- Puts popup.nvim on the runtimepath for the specs and the smoke config.
-- Looks at $POPUP_DIR, a lazy.nvim install, the dev checkout, then clones it
-- once into the git-ignored .tests dir.
local M = {}

--- @param root string repo root
function M.setup(root)
  local candidates = {
    vim.env.POPUP_DIR,
    vim.fn.stdpath "data" .. "/lazy/popup.nvim",
    vim.fn.expand "~/dev/hosua/nvim/popup.nvim",
    root .. "/.tests/popup.nvim",
  }
  for _, p in ipairs(candidates) do
    if p and p ~= "" and vim.uv.fs_stat(p .. "/lua/popup/init.lua") then
      vim.opt.runtimepath:append(p)
      return p
    end
  end
  local dest = root .. "/.tests/popup.nvim"
  vim.fn.system { "git", "clone", "--depth=1", "https://github.com/hosua/popup.nvim", dest }
  vim.opt.runtimepath:append(dest)
  return dest
end

return M
