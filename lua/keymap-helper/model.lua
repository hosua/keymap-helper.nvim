--- View model: turns the config plus what was scanned and what nvim has
--- mapped into an ordered list of sections, each with its groups of rows.
---
--- `gather` does the I/O; `build` is pure so the grouping and the
--- claimed/unclaimed split are tested on tables.
local M = {}

local scan = require "keymap-helper.scan"
local collect = require "keymap-helper.collect"

--- @class KeymapHelperRow
--- @field modes string
--- @field lhs string
--- @field desc string

--- @class KeymapHelperGroup
--- @field title string|nil nil = rows sit directly under the section title
--- @field rows KeymapHelperRow[]

--- @class KeymapHelperSectionState
--- @field id integer
--- @field title string
--- @field subtitle string|nil
--- @field groups KeymapHelperGroup[]
--- @field count integer

--- @class KeymapHelperState
--- @field sections KeymapHelperSectionState[]
--- @field footer string

--- Resolve a section's file list to absolute paths that exist.
--- @param section KeymapHelperSection
--- @return string[]
function M.section_paths(section)
  local paths = {}
  local config_dir = vim.fn.stdpath "config"
  for _, f in ipairs(section.files or {}) do
    local p = vim.fn.expand(f)
    if not vim.startswith(p, "/") then
      p = config_dir .. "/" .. p
    end
    if vim.uv.fs_stat(p) then
      table.insert(paths, p)
    end
  end
  for _, f in ipairs(section.runtime_files or {}) do
    local p = vim.api.nvim_get_runtime_file(f, false)[1]
    if p then
      table.insert(paths, p)
    end
  end
  return paths
end

--- @class KeymapHelperData
--- @field scanned table<integer, KeymapHelperScanEntry[]> section index -> parsed calls
--- @field live KeymapHelperLiveMap[]

--- Read every section's files and the live mappings.
--- @param cfg KeymapHelperConfig
--- @return KeymapHelperData
function M.gather(cfg)
  local scanned = {}
  for i, section in ipairs(cfg.sections) do
    local entries = {}
    for _, path in ipairs(M.section_paths(section)) do
      local lines = scan.read_lines(path)
      if lines then
        vim.list_extend(
          entries,
          scan.parse(lines, {
            header_pattern = cfg.header_pattern,
            map_functions = cfg.map_functions,
            fallback_group = section.title,
          })
        )
      end
    end
    scanned[i] = entries
  end
  return { scanned = scanned, live = collect.live(cfg.modes) }
end

--- Group consecutive rows that share a header, keeping file order.
--- @param entries KeymapHelperScanEntry[]
--- @param grouped boolean
--- @return KeymapHelperGroup[]
local function group_entries(entries, grouped)
  if not grouped then
    local rows = {}
    for _, e in ipairs(entries) do
      table.insert(rows, { modes = e.modes, lhs = e.lhs, desc = e.desc })
    end
    return #rows > 0 and { { rows = rows } } or {}
  end
  local groups, current = {}, nil
  for _, e in ipairs(entries) do
    if not current or current.title ~= e.group then
      current = { title = e.group, rows = {} }
      table.insert(groups, current)
    end
    table.insert(current.rows, { modes = e.modes, lhs = e.lhs, desc = e.desc })
  end
  return groups
end

--- @param cfg KeymapHelperConfig
--- @param data KeymapHelperData
--- @param normalize fun(lhs: string): string
--- @param display fun(lhs: string): string
--- @return KeymapHelperState
function M.build(cfg, data, normalize, display)
  -- mode .. canonical lhs of everything a file-backed section accounts for,
  -- so `rest` sections show only what is left.
  local claimed = {}
  for i in ipairs(cfg.sections) do
    for _, e in ipairs(data.scanned[i] or {}) do
      local key = normalize(e.lhs)
      for mode in e.modes:gmatch "[^,]+" do
        claimed[mode .. key] = true
      end
    end
  end

  local rest_rows = {}
  for _, m in ipairs(data.live) do
    if not claimed[m.mode .. m.lhs] and m.desc and m.desc ~= "" then
      table.insert(rest_rows, { modes = m.mode, lhs = display(m.lhs), desc = m.desc })
    end
  end
  table.sort(rest_rows, function(a, b)
    if a.lhs == b.lhs then
      return a.modes < b.modes
    end
    return a.lhs < b.lhs
  end)

  local sections, rest_used = {}, false
  for i, s in ipairs(cfg.sections) do
    local groups
    if s.rest and not rest_used then
      rest_used = true
      groups = #rest_rows > 0 and { { rows = rest_rows } } or {}
    else
      groups = group_entries(data.scanned[i] or {}, s.group_by == "header")
    end
    local count = 0
    for _, g in ipairs(groups) do
      count = count + #g.rows
    end
    table.insert(sections, { id = i, title = s.title, subtitle = s.subtitle, groups = groups, count = count })
  end

  return { sections = sections, footer = cfg.window.footer }
end

return M
