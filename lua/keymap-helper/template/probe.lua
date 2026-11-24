--- Runs inside the scratch nvim that `kh-template analyze` starts. It records
--- every global keymap set or delete while your config loads, then runs the
--- generated mappings file once more on top and writes what it saw to the file
--- named by $KH_PROBE_OUT. Nothing here needs plenary or the rest of the plugin,
--- because it is loaded with --cmd, before your config has built a runtimepath.
---
--- Environment, all set by analyze.lua:
---   KH_PROBE_REPLAY   generated mappings file to run after startup
---   KH_PROBE_TARGET   the mappings file on disk. What it sets during startup is
---                     dropped: the replay stands in for it
---   KH_PROBE_ENTRIES  JSON file, [{ id, modes, lhs }] of the template's maps
---   KH_PROBE_OUT      where the JSON result goes
---
--- Output: { leader, events, error?, warnings? }. See conflicts.lua for an event.
--- Buffer-local maps, `:map` commands and lazy.nvim `keys` stubs are not recorded.
local conflicts = require "keymap-helper.template.conflicts"

local M = {}

local S

local canon = conflicts.canon

local real_cache = {}
local function real(path)
  if real_cache[path] == nil then
    real_cache[path] = vim.uv.fs_realpath(path) or path
  end
  return real_cache[path]
end

--- Paths of the Lua files on the call stack, nearest first.
local function frames()
  local out = {}
  for level = 3, 40 do
    local info = debug.getinfo(level, "S")
    if not info then
      break
    end
    local src = info.source
    if
      src:sub(1, 1) == "@"
      and not src:find("/lua/vim/keymap.lua", 1, true)
      and not src:find("template/probe.lua", 1, true)
    then
      out[#out + 1] = src:sub(2)
    end
  end
  return out
end

--- Where a path belongs: "default:nvchad", "plugin:<name>", "config:<file>",
--- or nil for files whose maps are not ours to judge (Neovim itself, lazy.nvim).
local function label(path)
  local lower = path:lower()
  if lower:find("/nvchad/", 1, true) then
    return "default:nvchad"
  end
  if vim.startswith(path, vim.env.VIMRUNTIME or "\0") then
    return nil
  end
  local plugin = path:match "/lazy/([^/]+)/" or path:match "/pack/[^/]+/%a+/([^/]+)/"
  if plugin then
    return plugin ~= "lazy.nvim" and ("plugin:" .. plugin) or nil
  end
  local cfg = vim.fn.stdpath "config"
  for _, dir in ipairs { cfg, real(cfg) } do
    if vim.startswith(path, dir .. "/") then
      return "config:" .. path:sub(#dir + 2)
    end
  end
  return "plugin:" .. (path:match "([^/]+)/lua/" or "?")
end

local function source_of(stack)
  for _, path in ipairs(stack) do
    if path:lower():find("/nvchad/", 1, true) then
      return "default:nvchad"
    end
  end
  for _, path in ipairs(stack) do
    local l = label(path)
    if l then
      return l
    end
  end
end

local function in_file(stack, file)
  if not file or file == "" then
    return false
  end
  local want = real(file)
  for _, path in ipairs(stack) do
    if real(path) == want then
      return true
    end
  end
  return false
end

local function short(s, n)
  s = tostring(s):gsub("%s+", " ")
  return #s > n and (s:sub(1, n - 1) .. "…") or s
end

local function summarize(rhs)
  if type(rhs) == "function" then
    local i = debug.getinfo(rhs, "S")
    return ("function %s:%d"):format(vim.fn.fnamemodify((i.source:gsub("^@", "")), ":~"), i.linedefined)
  end
  local s = tostring(rhs or ""):gsub("^<[Cc][Mm][Dd]>%s*", ""):gsub("<[Cc][Rr]>$", "")
  return short(s, 120)
end

local function buffer_local(opts)
  return type(opts) == "table" and opts.buffer ~= nil and opts.buffer ~= false
end

--- Hand a replayed set to the template entry that wrote it, in order.
local function claim_entry(modes, lhs)
  local key = table.concat(modes, "")
  for _, e in ipairs(S.entries) do
    if not e.used and e.lhs == lhs and e.key == key then
      e.used = true
      return "template:" .. e.id
    end
  end
  return "template:raw"
end

local function record_set(mode, lhs, rhs, opts)
  if buffer_local(opts) then
    return
  end
  local stack = frames()
  local replayed = S.replay and in_file(stack, S.replay_file)
  local modes, key = conflicts.modes(mode), canon(lhs)
  local source
  if replayed then
    source = claim_entry(modes, key)
  else
    source = source_of(stack)
    if not source or (S.target and in_file(stack, S.target) and source ~= "default:nvchad") then
      return
    end
  end
  local desc = type(opts) == "table" and type(opts.desc) == "string" and opts.desc or nil
  for _, m in ipairs(modes) do
    S.events[#S.events + 1] =
      { op = "set", mode = m, lhs = key, source = source, desc = desc, summary = summarize(rhs) }
  end
end

local function record_del(mode, lhs, opts)
  if buffer_local(opts) then
    return
  end
  local stack = frames()
  local source = (S.replay and in_file(stack, S.replay_file)) and "template:raw" or source_of(stack)
  if not source or (S.target and in_file(stack, S.target) and not S.replay) then
    return
  end
  for _, m in ipairs(conflicts.modes(mode)) do
    S.events[#S.events + 1] = { op = "del", mode = m, lhs = canon(lhs), source = source }
  end
end

local function read_json(path)
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  local text = fh:read "*a"
  fh:close()
  return vim.json.decode(text)
end

local function write_out()
  local fh = assert(io.open(S.out, "w"))
  fh:write(
    vim.json.encode { leader = vim.g.mapleader or "\\", events = S.events, error = S.error, warnings = S.warnings }
  )
  fh:close()
end

--- Run the generated file once on top of the loaded config.
local function replay()
  local fn, err = loadfile(S.replay_file)
  if not fn then
    S.error = "the generated file does not compile: " .. tostring(err)
    return
  end
  S.replay = true
  local ok, e = xpcall(fn, debug.traceback)
  S.replay = false
  if not ok then
    S.error = "the generated file stopped with an error: " .. short(tostring(e):match "^[^\n]*", 300)
  end
end

--- Errors the config printed while it loaded. They explain a missing leader or
--- missing defaults, so the caller shows them as a warning.
local function startup_errors()
  local out = {}
  local ok, res = pcall(vim.api.nvim_exec2, "messages", { output = true })
  if ok then
    for line in vim.gsplit(res.output or "", "\n", { plain = true }) do
      if
        line:match "^E%d+:"
        or line:find("Error detected while processing", 1, true)
        or line:find("Error executing", 1, true)
      then
        out[#out + 1] = short(line, 300)
      end
    end
  end
  return out
end

local function run()
  S.warnings = startup_errors()
  local ok, err = pcall(replay)
  if not ok then
    S.error = tostring(err)
  end
  pcall(write_out)
  vim.cmd "qa!"
end

--- Hook the keymap functions, then run the replay once startup is done.
--- Called with `--cmd`, so it runs before your config.
function M.install()
  if S then
    return
  end
  local entries = {}
  for _, e in ipairs(read_json(vim.env.KH_PROBE_ENTRIES or "") or {}) do
    entries[#entries + 1] = { id = e.id, modes = e.modes, lhs = e.lhs }
  end
  S = {
    events = {},
    depth = 0,
    replay = false,
    replay_file = vim.env.KH_PROBE_REPLAY,
    target = vim.env.KH_PROBE_TARGET,
    out = vim.env.KH_PROBE_OUT,
    entries = entries,
  }

  local set, del = vim.keymap.set, vim.keymap.del
  local api_set, api_del = vim.api.nvim_set_keymap, vim.api.nvim_del_keymap

  vim.keymap.set = function(mode, lhs, rhs, opts)
    S.depth = S.depth + 1
    local ok, err = pcall(set, mode, lhs, rhs, opts)
    S.depth = S.depth - 1
    if not ok then
      error(err, 0)
    end
    record_set(mode, lhs, rhs, opts)
  end
  vim.keymap.del = function(mode, lhs, opts)
    S.depth = S.depth + 1
    local ok, err = pcall(del, mode, lhs, opts)
    S.depth = S.depth - 1
    -- The real config already deleted this key, so a second delete fails.
    -- The replay still counts it: the file did ask for it.
    if not ok and not S.replay then
      error(err, 0)
    end
    record_del(mode, lhs, opts)
  end
  vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
    if S.depth > 0 then
      return api_set(mode, lhs, rhs, opts)
    end
    local result = api_set(mode, lhs, rhs, opts)
    record_set(mode, lhs, opts and opts.callback or rhs, opts)
    return result
  end
  vim.api.nvim_del_keymap = function(mode, lhs)
    if S.depth > 0 then
      return api_del(mode, lhs)
    end
    local ok, err = pcall(api_del, mode, lhs)
    if not ok and not S.replay then
      error(err, 0)
    end
    record_del(mode, lhs)
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      -- <leader> is only known once the config has set mapleader.
      for _, e in ipairs(S.entries) do
        e.lhs = canon(e.lhs)
        e.key = table.concat(conflicts.modes(e.modes), "")
      end
      -- Anything the config scheduled while loading (NvChad requires its
      -- mappings that way) runs before this timer fires.
      vim.defer_fn(run, 150)
    end,
  })
end

return M
