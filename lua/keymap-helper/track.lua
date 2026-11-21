--- Opt-in registry of who called vim.keymap.set. Neovim records no source
--- for string-rhs maps set from Lua, so wrapping vim.keymap.set (early, from
--- init.lua) is the only exact way to know which file set a map.
-- Required now, not on first use: the first recorded call usually comes from
-- lazy.nvim's setup(), after it has reset 'runtimepath', when a late require
-- could fail or force-load this plugin halfway through startup.
local collect = require "keymap-helper.collect"

local M = {}

--- @class KeymapHelperTracked
--- @field source string absolute path (no "@")
--- @field line integer

-- Frames whose source matches one of these are plumbing, not the caller.
M.SKIP = {
  "^@vim/",
  "/runtime/lua/vim/",
  "/lazy%.nvim/lua/lazy/",
  "/lua/keymap%-helper/",
  "/which%-key%.nvim/lua/which%-key/",
}

-- A map set from here is a lazy.nvim `keys` stub: the plugin it belongs to is
-- known to the lazy_keys layer, and the frames above it are just whoever
-- called lazy.setup(), so recording them would credit the plugin's keys to
-- the user's init.lua.
M.STOP = "/lazy%.nvim/lua/lazy/core/handler/keys%.lua$"

local MAX_LEVEL = 30

local registry = {}
local original
local active
local wrapper

--- Concrete mode letters a vim.keymap.set `modes` argument covers.
--- @param modes string|string[]
--- @return string[]
function M.expand_modes(modes)
  local list = type(modes) == "table" and modes or { modes }
  local out, seen = {}, {}
  local function add(m)
    if not seen[m] then
      seen[m] = true
      table.insert(out, m)
    end
  end
  for _, m in ipairs(list) do
    if m == "" or m == " " then
      for _, x in ipairs { "n", "v", "x", "s", "o" } do
        add(x)
      end
    elseif m == "v" then
      for _, x in ipairs { "v", "x", "s" } do
        add(x)
      end
    elseif m == "!" then
      for _, x in ipairs { "!", "i", "c" } do
        add(x)
      end
    else
      add(m)
    end
  end
  return out
end

--- First stack frame that is not plumbing.
--- @param frames { source: string|nil, currentline: integer|nil }[]
--- @param skip string[]
--- @return KeymapHelperTracked|nil
function M.pick_caller(frames, skip)
  for _, f in ipairs(frames) do
    local src = f.source
    if type(src) == "string" and src:sub(1, 1) == "@" then
      if src:find(M.STOP) then
        return nil
      end
      local skipped = false
      for _, pat in ipairs(skip) do
        if src:find(pat) then
          skipped = true
          break
        end
      end
      if not skipped then
        return { source = src:sub(2), line = f.currentline or 0 }
      end
    end
  end
end

function M.installed()
  return wrapper ~= nil and vim.keymap.set == wrapper
end

--- @return boolean true when our wrapper is vim.keymap.set after the call
function M.install()
  if M.installed() then
    return true
  end
  if wrapper ~= nil then
    return false
  end
  -- Each wrapper keeps its own original, so a reference captured earlier
  -- (`local map = vim.keymap.set` at the top of a module) keeps working after
  -- uninstall(); `active` stops such stale wrappers from recording.
  local orig = vim.keymap.set
  local state = { active = true }
  original, active = orig, state
  wrapper = function(modes, lhs, rhs, opts)
    local caller
    if state.active and (opts == nil or opts.buffer == nil or opts.buffer == false) then
      local frames = {}
      for level = 2, MAX_LEVEL do
        local info = debug.getinfo(level, "Sl")
        if not info then
          break
        end
        table.insert(frames, info)
      end
      caller = M.pick_caller(frames, M.SKIP)
    end
    orig(modes, lhs, rhs, opts)
    if caller then
      -- Never let bookkeeping fail the user's own mapping call.
      pcall(function()
        for _, m in ipairs(M.expand_modes(modes)) do
          registry[m .. collect.normalize(lhs)] = caller
        end
      end)
    end
  end
  vim.keymap.set = wrapper
  return true
end

--- @return boolean true when the original was restored
function M.uninstall()
  if not M.installed() then
    return false
  end
  vim.keymap.set = original
  active.active = false
  wrapper, original, active = nil, nil, nil
  return true
end

--- @return table<string, KeymapHelperTracked> shallow copy
function M.registry()
  return vim.tbl_extend("force", {}, registry)
end

function M.reset()
  registry = {}
end

return M
