--- `kh-template analyze`: who defines each key, found by running your real
--- config. A scratch `nvim --headless` loads your config with probe.lua
--- recording every keymap call, then runs the file the template generates, and
--- conflicts.lua groups what was recorded.
---
--- The scratch nvim is a normal start of your config, so it can do whatever
--- your config does at startup (lazy.nvim may install a missing plugin, shada
--- is skipped with -i NONE). Point XDG_DATA_HOME, XDG_STATE_HOME and
--- XDG_CACHE_HOME at throwaway directories for a run that touches nothing;
--- the plugins your config needs must be reachable there.
local conflicts = require "keymap-helper.template.conflicts"
local generate = require "keymap-helper.template.generate"
local json = require "keymap-helper.template.json"

local M = {}

M.DEFAULT_TIMEOUT = 30

local function write(path, text)
  local fh = assert(io.open(path, "w"))
  fh:write(text)
  fh:close()
end

local function read(path)
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  local text = fh:read "*a"
  fh:close()
  return text
end

--- The maps the probe should match replayed calls to: global ones only.
local function entry_list(tpl)
  local out = {}
  for _, e in ipairs(tpl.entries) do
    local local_map = (e.opts and e.opts.buffer ~= nil and e.opts.buffer ~= false)
      or (e.opts_raw and e.opts_raw.buffer ~= nil)
    if e.kind == "map" and not local_map then
      out[#out + 1] = { id = e.id, modes = e.modes, lhs = e.lhs }
    end
  end
  return out
end

--- @param args { tpl: table, root: string, target: string, template_name: string, timeout: number|nil, nvim: string|nil, plugin_root: string }
--- @return table|nil result, string|nil err
function M.run(args)
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local function done(res, err)
    vim.fn.delete(tmp, "rf")
    return res, err
  end

  write(tmp .. "/replay.lua", generate.render(args.tpl, { target = args.target, template_name = args.template_name }))
  write(
    tmp .. "/entries.json",
    vim.json.encode(vim.tbl_isempty(entry_list(args.tpl)) and vim.empty_dict() or entry_list(args.tpl))
  )
  local env = {
    KH_PROBE_REPLAY = tmp .. "/replay.lua",
    KH_PROBE_TARGET = args.target,
    KH_PROBE_ENTRIES = tmp .. "/entries.json",
    KH_PROBE_OUT = tmp .. "/out.json",
  }
  -- The config the scratch nvim loads is the root. When that is not where
  -- nvim looks by default, a symlink under a temp XDG_CONFIG_HOME points at it.
  local default_cfg = vim.uv.fs_realpath(vim.fn.stdpath "config")
  if vim.uv.fs_realpath(args.root) ~= default_cfg then
    vim.fn.mkdir(tmp .. "/xdg", "p")
    vim.uv.fs_symlink(args.root, tmp .. "/xdg/" .. (vim.env.NVIM_APPNAME or "nvim"))
    env.XDG_CONFIG_HOME = tmp .. "/xdg"
  end

  local lua_path = ("%s/lua/?.lua;%s/lua/?/init.lua;"):format(args.plugin_root, args.plugin_root)
  local timeout = args.timeout or M.DEFAULT_TIMEOUT
  local res = vim
    .system({
      args.nvim or vim.v.progpath,
      "--headless",
      "-i",
      "NONE",
      "-n",
      "--cmd",
      ("lua package.path = %q .. package.path"):format(lua_path),
      "--cmd",
      "lua require('keymap-helper.template.probe').install()",
    }, { env = env, text = true, timeout = timeout * 1000, stdin = false })
    :wait()

  local text = read(tmp .. "/out.json")
  if not text then
    if res.signal ~= 0 or res.code == 124 or res.code == 143 then
      return done(nil, ("analysis timed out after %ds: your config did not finish starting"):format(timeout))
    end
    local tail = vim.trim((res.stderr or ""):sub(-400))
    return done(nil, "the scratch nvim exited without a result" .. (tail ~= "" and (":\n" .. tail) or ""))
  end
  local out = json.decode(text)
  if not out then
    return done(nil, "the scratch nvim wrote an unreadable result")
  end
  local built = conflicts.build(out.events or {})
  return done {
    status = out.error and "partial" or "ok",
    source = "replay",
    leader = out.leader,
    keys = built.keys,
    counts = built.counts,
    error = out.error,
  }
end

return M
