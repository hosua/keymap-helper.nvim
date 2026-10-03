--- Names for <leader>x prefixes, borrowed from which-key when it is loaded.
local M = {}

--- @param mappings table[] which-key's resolved mappings
--- @param display fun(lhs: string): string
--- @return table<string, string> display prefix -> group name
function M.groups(mappings, display)
  local out = {}
  for _, km in ipairs(mappings) do
    if km.group == true and type(km.desc) == "string" and (km.mode == nil or km.mode == "n") then
      local key = display(km.lhs)
      if out[key] == nil then
        out[key] = (km.desc:gsub("^%+", ""))
      end
    end
  end
  return out
end

--- Private which-key API, so every access is pcall'd.
--- @param display fun(lhs: string): string
--- @return table<string, string>
function M.load(display)
  if not package.loaded["which-key"] then
    return {}
  end
  local ok, mappings = pcall(function()
    return require("which-key.config").mappings
  end)
  if not ok or type(mappings) ~= "table" then
    return {}
  end
  local ok2, out = pcall(M.groups, mappings, display)
  return ok2 and out or {}
end

return M
