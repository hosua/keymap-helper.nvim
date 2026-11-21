--- Turns a file path (or a debug source string) into "where did this come
--- from": the user's config, a named plugin, Neovim itself, or unknown.
---
--- `path` and `source` are pure: everything they need is passed in `env`.
--- Only `env` touches nvim.
local M = {}

--- @class KeymapHelperClassifyEnv
--- @field config_dirs string[] absolute, no trailing "/"
--- @field lazy_root string|nil absolute, no trailing "/"
--- @field vimruntime string $VIMRUNTIME, no trailing "/"
--- @field rtp string[] runtimepath entries, no trailing "/"

--- @class KeymapHelperPlace
--- @field kind "config"|"plugin"|"builtin"|"unknown"
--- @field plugin string|nil
--- @field file string|nil

local function under(p, dir)
  return p == dir or p:sub(1, #dir + 1) == dir .. "/"
end

local function basename(p)
  return p:match "([^/]+)/*$" or p
end

local function parent(p)
  return p:match "^(.*)/[^/]+/*$" or ""
end

--- @param path string
--- @param env KeymapHelperClassifyEnv
--- @return KeymapHelperPlace
function M.path(path, env)
  if env.vimruntime and env.vimruntime ~= "" and under(path, env.vimruntime) then
    return { kind = "builtin", file = path }
  end

  local pack = path:match "/pack/[^/]+/start/([^/]+)/" or path:match "/pack/[^/]+/opt/([^/]+)/"
  if pack then
    return { kind = "plugin", plugin = pack, file = path }
  end

  if env.lazy_root and under(path, env.lazy_root) then
    local name = path:sub(#env.lazy_root + 2):match "^([^/]+)"
    if name then
      return { kind = "plugin", plugin = name, file = path }
    end
  end

  for _, dir in ipairs(env.config_dirs or {}) do
    if under(path, dir) then
      return { kind = "config", file = path }
    end
  end

  local skip = { [env.vimruntime] = true }
  for _, dir in ipairs(env.config_dirs or {}) do
    skip[dir] = true
  end
  local best
  for _, e in ipairs(env.rtp or {}) do
    if not skip[e] and under(path, e) and (not best or #e > #best) then
      best = e
    end
  end
  if best then
    local name = basename(best)
    if name == "after" then
      name = basename(parent(best))
    end
    return { kind = "plugin", plugin = name, file = path }
  end

  return { kind = "unknown", file = path }
end

--- @param source string|nil debug.getinfo "source" field
--- @param env KeymapHelperClassifyEnv
--- @return KeymapHelperPlace|nil
function M.source(source, env)
  if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
    return nil
  end
  if vim.startswith(source, "@vim/") then
    return { kind = "builtin" }
  end
  return M.path(source:sub(2), env)
end

--- Neovim's default maps carry a desc like ":help Y-default".
--- @param desc string|nil
--- @return boolean
function M.is_builtin_desc(desc)
  return type(desc) == "string" and desc:match "^:help .+%-default$" ~= nil
end

local function strip(p)
  return (vim.fs.normalize(p):gsub("/+$", ""))
end

--- @return KeymapHelperClassifyEnv
function M.env()
  local config = vim.fn.stdpath "config"
  local dirs = { strip(config) }
  local real = vim.uv.fs_realpath(config)
  if real and strip(real) ~= dirs[1] then
    table.insert(dirs, strip(real))
  end

  local lazy_root
  local loaded = package.loaded["lazy.core.config"]
  if loaded then
    local ok, root = pcall(function()
      return loaded.options.root
    end)
    if ok and type(root) == "string" then
      lazy_root = strip(root)
    end
  end
  if not lazy_root then
    local guess = vim.fn.stdpath "data" .. "/lazy"
    local stat = vim.uv.fs_stat(guess)
    if stat and stat.type == "directory" then
      lazy_root = strip(guess)
    end
  end

  local rtp = {}
  for _, p in ipairs(vim.api.nvim_list_runtime_paths()) do
    table.insert(rtp, strip(p))
  end

  return { config_dirs = dirs, lazy_root = lazy_root, vimruntime = strip(vim.env.VIMRUNTIME or ""), rtp = rtp }
end

return M
