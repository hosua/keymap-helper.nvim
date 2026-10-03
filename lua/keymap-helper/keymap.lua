--- The key that opens the list. No other requires, so plugin/keymap-helper.lua
--- can load it at startup without pulling in the rest of the plugin.
local M = {}

M.DEFAULT = "<leader>km"
M.RHS = "<cmd>KeymapHelper<cr>"

--- @type string|false
local wanted = M.DEFAULT
--- @type string|nil the lhs this module mapped
local installed

local function current(lhs)
  return vim.fn.maparg(lhs, "n", false, true)
end

--- Map `lhs` to :KeymapHelper in normal mode. nil re-applies the last request
--- (the default until setup() says otherwise), false removes the plugin's map.
--- A key the user already mapped is left alone.
--- @param lhs string|false|nil
--- @return string|nil installed the lhs the plugin has mapped now
function M.apply(lhs)
  if lhs ~= nil then
    wanted = lhs
  end
  if installed and installed ~= wanted then
    -- Only delete what is still ours: the user may have remapped the key since.
    if current(installed).rhs == M.RHS then
      vim.keymap.del("n", installed)
    end
    installed = nil
  end
  if not wanted or installed == wanted then
    return installed
  end
  if not vim.tbl_isempty(current(wanted)) then
    return nil
  end
  vim.keymap.set("n", wanted, M.RHS, { desc = "show the keymap list" })
  installed = wanted
  return installed
end

return M
