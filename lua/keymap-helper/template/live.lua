--- The analysis snapshot `:KeymapHelper edit` hands to the terminal UI, built
--- inside the running nvim without running any of your code and without a
--- second nvim. Same shape as `kh-template analyze` prints, with `source`
--- set to "static".
---
--- A replay can see a default that the template overrode. The live session
--- cannot: the override already replaced it. So the defaults are read as text,
--- from every section of your config that names `runtime_files` (the NvChad
--- defaults file in the usual setup), the same way the list scans files. A
--- default whose key is not mapped any more is reported as removed. That is a
--- guess: a map that never loaded looks the same. A delete followed by a new
--- map on the same key shows as an override.
local conflicts = require "keymap-helper.template.conflicts"
local scan = require "keymap-helper.scan"

local M = {}

local function default_name(path)
  local lower = path:lower()
  if lower:find("/nvchad/", 1, true) then
    return "nvchad"
  end
  return path:match "/lua/([^/]+)/[^/]+$" or vim.fs.basename(path)
end

--- @param cfg KeymapHelperConfig|nil defaults to the resolved plugin config
--- @return table snapshot
function M.snapshot(cfg)
  cfg = cfg or require("keymap-helper.config").get()
  local model = require "keymap-helper.model"
  local events = {}
  for _, section in ipairs(cfg.sections) do
    if section.runtime_files then
      local only_runtime = { runtime_files = section.runtime_files }
      for _, path in ipairs(model.section_paths(only_runtime)) do
        local lines = scan.read_lines(path)
        local entries = lines
            and scan.parse(lines, {
              header_pattern = cfg.header_pattern,
              map_functions = cfg.map_functions,
              fallback_group = "",
            })
          or {}
        for _, e in ipairs(entries) do
          local lhs = vim.fn.keytrans(vim.keycode(e.lhs))
          for _, m in ipairs(conflicts.modes(vim.split(e.modes, ",", { plain = true, trimempty = true }))) do
            events[#events + 1] = {
              op = "set",
              mode = m,
              lhs = lhs,
              source = "default:" .. default_name(path),
              desc = e.desc ~= "" and e.desc or nil,
            }
          end
        end
      end
    end
  end

  local live = {}
  for _, mode in ipairs { "n", "x", "s", "o", "i", "c", "t" } do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      live[mode .. vim.fn.keytrans(m.lhsraw or vim.keycode(m.lhs))] = true
    end
  end
  local gone = {}
  for _, ev in ipairs(events) do
    if not live[ev.mode .. ev.lhs] then
      gone[#gone + 1] = { op = "del", mode = ev.mode, lhs = ev.lhs, source = "template:raw" }
    end
  end
  vim.list_extend(events, gone)

  local built = conflicts.build(events)
  -- build() reports only conflicts. The UI needs every default key to compare
  -- against the template, so list the defaults themselves.
  local keys, seen = {}, {}
  for _, ev in ipairs(events) do
    if ev.op == "set" then
      local id = ev.mode .. "\0" .. ev.lhs
      local k = seen[id]
      if not k then
        k = { mode = ev.mode, lhs = ev.lhs, defs = {}, removed = {} }
        seen[id] = k
        keys[#keys + 1] = k
      end
      k.defs[#k.defs + 1] = { source = ev.source, desc = ev.desc }
    end
  end
  for _, r in ipairs(built.keys) do
    local k = seen[r.mode .. "\0" .. r.lhs]
    if k then
      k.removed = r.removed
      if #r.removed > 0 then
        k.defs = {}
      end
    end
  end
  return {
    status = "ok",
    source = "static",
    leader = vim.g.mapleader or "\\",
    keys = keys,
    counts = { duplicates = 0, overrides = 0, removed = built.counts.removed },
    note = "defaults read as text from the live session: no replay",
  }
end

return M
