--- Section matchers: does this live map belong in this section? Pure.
local M = {}

M.MATCHER_KEYS = { "config", "builtin", "plugin", "files", "runtime_files", "lhs", "desc", "mode", "fn" }

--- @class KeymapHelperMatchMap
--- @field mode string
--- @field lhs string display form ("<leader>gb")
--- @field key string canonical form (what normalize/collect give)
--- @field desc string "" when none
--- @field rhs string|nil

--- @param section KeymapHelperSection
--- @return boolean
function M.has_files(section)
  return section.files ~= nil or section.runtime_files ~= nil
end

--- A user's bad Lua pattern means "no match", not an error on every open.
--- @param text string
--- @param pattern string
--- @return boolean
local function finds(text, pattern)
  local ok, hit = pcall(string.find, text, pattern)
  return ok and hit ~= nil
end

local function one_of(value, list)
  if type(list) == "string" then
    list = { list }
  end
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function plugin_ok(want, origin)
  if origin.kind ~= "plugin" then
    return false
  end
  if want == true then
    return true
  end
  local name = (origin.plugin or ""):lower()
  for _, w in ipairs(type(want) == "string" and { want } or want) do
    if type(w) == "string" and w:lower() == name then
      return true
    end
  end
  return false
end

--- @param section KeymapHelperSection
--- @param m KeymapHelperMatchMap
--- @param origin KeymapHelperOrigin
--- @param file_hit boolean
--- @return boolean
function M.section(section, m, origin, file_hit)
  local any = false
  for _, k in ipairs(M.MATCHER_KEYS) do
    if section[k] ~= nil and section[k] ~= false then
      any = true
      break
    end
  end
  if not any and section.rest ~= true then
    return false
  end

  if section.config == true and origin.kind ~= "config" then
    return false
  end
  if section.builtin == true and origin.kind ~= "builtin" then
    return false
  end
  if section.plugin ~= nil and section.plugin ~= false and not plugin_ok(section.plugin, origin) then
    return false
  end
  if M.has_files(section) and not file_hit then
    return false
  end
  if section.lhs ~= nil and not finds(m.lhs, section.lhs) then
    return false
  end
  if section.desc ~= nil and not finds(m.desc, section.desc) then
    return false
  end
  if section.mode ~= nil and not one_of(m.mode, section.mode) then
    return false
  end
  if section.fn ~= nil then
    local ok, res = pcall(section.fn, m, origin)
    if not ok or not res then
      return false
    end
  end
  return true
end

return M
