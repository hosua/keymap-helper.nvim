-- Puts popup.nvim and plenary.nvim on the runtimepath for the specs and the
-- smoke config. Each is looked up at $<NAME>_DIR, a lazy.nvim install, the dev
-- checkouts, then cloned once into the git-ignored .tests dir.
local M = {}

local DEPS = {
  {
    name = "popup.nvim",
    env = "POPUP_DIR",
    probe = "/lua/popup/init.lua",
    url = "https://github.com/hosua/popup.nvim",
  },
  {
    name = "plenary.nvim",
    env = "PLENARY_DIR",
    probe = "/lua/plenary/path.lua",
    url = "https://github.com/nvim-lua/plenary.nvim",
  },
}

--- @param root string repo root
function M.setup(root)
  local found = {}
  for _, dep in ipairs(DEPS) do
    local candidates = {
      vim.fn.stdpath "data" .. "/lazy/" .. dep.name,
      vim.fn.expand("~/dev/hosua/nvim/" .. dep.name),
      vim.fn.expand("~/dev/hosua/nvim/submodules/" .. dep.name),
      root .. "/.tests/" .. dep.name,
    }
    if vim.env[dep.env] and vim.env[dep.env] ~= "" then
      table.insert(candidates, 1, vim.env[dep.env])
    end
    local path
    for _, p in ipairs(candidates) do
      if vim.uv.fs_stat(p .. dep.probe) then
        path = p
        break
      end
    end
    if not path then
      path = root .. "/.tests/" .. dep.name
      vim.fn.system { "git", "clone", "--depth=1", dep.url, path }
    end
    vim.opt.runtimepath:append(path)
    found[dep.name] = path
  end
  return found
end

return M
