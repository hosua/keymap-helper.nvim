--- Works out where a live mapping came from, trying the most exact evidence
--- first: track() registry, lazy.nvim keys specs, the callback's source,
--- the script id Neovim recorded, then the config text index, then a desc
--- heuristic. `resolve` is pure given the functions in its context.
local M = {}

local classify = require "keymap-helper.classify"

--- @class KeymapHelperOrigin
--- @field kind "config"|"plugin"|"builtin"|"unknown"
--- @field plugin string|nil
--- @field file string|nil
--- @field group string|nil from the index
--- @field order integer|nil from the index
--- @field via "track"|"lazy_keys"|"callback"|"sid"|"index"|"heuristic"|"none"

--- @class KeymapHelperOriginCtx
--- @field tracked table<string, KeymapHelperTracked>
--- @field lazy_keys table<string, string> mode..canonical lhs -> plugin name
--- @field index KeymapHelperIndex
--- @field getinfo fun(fn: function): string|nil callback -> debug source
--- @field scriptinfo fun(sid: integer): string|nil sid -> absolute path
--- @field env KeymapHelperClassifyEnv

-- lazy.nvim installs its own stub as the callback of every lazy `keys` map,
-- so a callback from this file says nothing about the real owner.
M.LAZY_STUB = "/lazy%.nvim/lua/lazy/core/handler/keys%.lua$"

local function with_via(place, via)
  return vim.tbl_extend("force", {}, place, { via = via })
end

--- @param map KeymapHelperLiveMap
--- @param ctx KeymapHelperOriginCtx
--- @return KeymapHelperOrigin
function M.resolve(map, ctx)
  local key = map.mode .. map.lhs
  local hit = ctx.index[key]
  local o

  local t = ctx.tracked[key]
  if t then
    o = with_via(classify.path(t.source, ctx.env), "track")
  end

  if not o and ctx.lazy_keys[key] then
    o = { kind = "plugin", plugin = ctx.lazy_keys[key], via = "lazy_keys" }
  end

  if not o and map.callback then
    local s = ctx.getinfo(map.callback)
    if s and not s:find(M.LAZY_STUB) then
      local place = classify.source(s, ctx.env)
      if place then
        o = with_via(place, "callback")
      end
    end
  end

  if not o and (map.sid or 0) > 0 and (map.lnum or 0) > 0 then
    local p = ctx.scriptinfo(map.sid)
    if p then
      o = with_via(classify.path(p, ctx.env), "sid")
    end
  end

  if not o and hit then
    o = { kind = "config", file = hit.file, via = "index" }
  end

  if not o and classify.is_builtin_desc(map.desc) then
    o = { kind = "builtin", via = "heuristic" }
  end

  o = o or { kind = "unknown", via = "none" }

  if hit and o.kind == "config" and (o.file == nil or o.file == hit.file) then
    o.group = hit.group
    o.order = hit.order
  end
  return o
end

--- Map keys lazy.nvim loads a plugin for (private API, hence the shape checks).
--- @param plugins table lazy's `require("lazy.core.config").plugins`
--- @param normalize fun(lhs: string): string
--- @return table<string, string>
function M.lazy_keys_from(plugins, normalize)
  local out = {}
  for _, p in pairs(plugins) do
    local keys = p._ and p._.handlers and p._.handlers.keys
    for _, k in pairs(keys or {}) do
      if not k.ft and type(k.lhs) == "string" then
        local modes = type(k.mode) == "table" and k.mode or { k.mode or "n" }
        for _, mode in ipairs(modes) do
          local id = mode .. normalize(k.lhs)
          if out[id] == nil then
            out[id] = p.name
          end
        end
      end
    end
  end
  return out
end

--- @param fn function
--- @return string|nil
function M.getinfo(fn)
  local ok, info = pcall(debug.getinfo, fn, "S")
  return ok and info and info.source or nil
end

--- @param sid integer
--- @return string|nil
function M.scriptinfo(sid)
  local ok, info = pcall(vim.fn.getscriptinfo, { sid = sid })
  if ok and type(info) == "table" and info[1] then
    return info[1].name
  end
end

--- @param cfg KeymapHelperConfig
--- @param normalize fun(lhs: string): string
--- @return KeymapHelperOriginCtx ctx, { files: integer, capped: boolean } stats
function M.context(cfg, normalize)
  local detect = cfg.detect or {}
  local index, stats = {}, { files = 0, capped = false }
  if detect.scan_config then
    index, stats = require("keymap-helper.index").build(vim.fn.stdpath "config", {
      header_pattern = cfg.header_pattern,
      map_functions = cfg.map_functions,
      max_files = detect.max_files,
    }, normalize)
  end

  local lazy_keys = {}
  if detect.lazy_keys and package.loaded["lazy.core.config"] then
    local ok, res = pcall(function()
      return M.lazy_keys_from(require("lazy.core.config").plugins, normalize)
    end)
    if ok then
      lazy_keys = res
    end
  end

  return {
    tracked = require("keymap-helper.track").registry(),
    lazy_keys = lazy_keys,
    index = index,
    getinfo = M.getinfo,
    scriptinfo = M.scriptinfo,
    env = classify.env(),
  },
    stats
end

return M
