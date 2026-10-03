--- View model: turns the config plus what was scanned and what nvim has
--- mapped into an ordered list of sections, each with its groups of rows.
---
--- `gather` does the I/O; `build` is pure so the grouping and the
--- claimed/unclaimed split are tested on tables.
local M = {}

local scan = require "keymap-helper.scan"
local collect = require "keymap-helper.collect"
local match = require "keymap-helper.match"
local group = require "keymap-helper.group"

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
--- @field collapsed boolean initial fold state from the config

--- @class KeymapHelperState
--- @field sections KeymapHelperSectionState[]
--- @field footer string
--- @field intro KeymapHelperIntro|nil
--- @field intro_collapsed boolean initial fold state of the intro

--- Mutable-by-replacement UI state: which sections are folded.
--- @class KeymapHelperView
--- @field collapsed table<integer|string, boolean> section id (or "intro") -> folded

--- @alias KeymapHelperAction
--- | { type: "toggle"|"open"|"close", id: integer }
--- | { type: "open_all"|"close_all" }

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
--- @field scanned table<integer, KeymapHelperScanEntry[]> section index -> parsed calls (only for sections with files)
--- @field live KeymapHelperLiveMap[] each may carry .origin (nil = unknown)
--- @field wk_groups table<string, string>|nil display prefix -> which-key group name
--- @field stats { files: integer, capped: boolean }|nil config index stats, for :checkhealth

--- Mode letters of every scanned entry, so a file that maps `x` or `t` is
--- looked up in the live maps even when `cfg.modes` leaves it out.
--- @param cfg KeymapHelperConfig
--- @param scanned table<integer, KeymapHelperScanEntry[]>
--- @return string[]
local function query_modes(cfg, scanned)
  local out, seen = {}, {}
  local function add(m)
    if not seen[m] then
      seen[m] = true
      table.insert(out, m)
    end
  end
  for _, m in ipairs(cfg.modes) do
    add(m)
  end
  for i in ipairs(cfg.sections) do
    for _, e in ipairs(scanned[i] or {}) do
      for m in e.modes:gmatch "[^,]+" do
        add(m)
      end
    end
  end
  return out
end

--- Read every section's files, the live mappings and where each came from.
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

  local origin = require "keymap-helper.origin"
  local ctx, stats = origin.context(cfg, collect.normalize)
  local live = {}
  for _, m in ipairs(collect.live(query_modes(cfg, scanned))) do
    table.insert(live, vim.tbl_extend("force", m, { origin = origin.resolve(m, ctx) }))
  end

  local wk_groups = {}
  if cfg.detect.which_key then
    wk_groups = require("keymap-helper.whichkey").load(collect.display)
  end
  return { scanned = scanned, live = live, wk_groups = wk_groups, stats = stats }
end

--- mode .. canonical lhs -> { group, order } for one file-backed section.
local function file_set(entries, normalize)
  local set = {}
  for n, e in ipairs(entries) do
    local key = normalize(e.lhs)
    for mode in e.modes:gmatch "[^,]+" do
      if set[mode .. key] == nil then
        set[mode .. key] = { group = e.group, order = n }
      end
    end
  end
  return set
end

--- Section indices in match order: ordinary sections, then `rest` ones.
local function match_order(sections)
  local order, has_rest = {}, false
  for i, s in ipairs(sections) do
    if not s.rest then
      table.insert(order, i)
    end
  end
  for i, s in ipairs(sections) do
    if s.rest then
      has_rest = true
      table.insert(order, i)
    end
  end
  return order, has_rest
end

local UNKNOWN_ORIGIN = { kind = "unknown", via = "none" }

--- Deal every live map to the first section that wants it.
--- @return table<integer, KeymapHelperItem[]> items per section index (the implicit Other is #sections + 1)
local function assign(cfg, data, normalize, display)
  local sections = cfg.sections
  local filesets = {}
  for i, s in ipairs(sections) do
    if match.has_files(s) then
      filesets[i] = file_set(data.scanned[i] or {}, normalize)
    end
  end
  local order, has_rest = match_order(sections)
  local items = {}

  for _, live in ipairs(data.live) do
    local desc = live.desc or ""
    local m = { mode = live.mode, lhs = display(live.lhs), key = live.lhs, desc = desc, rhs = live.rhs }
    local origin = live.origin or UNKNOWN_ORIGIN
    local visible = cfg.show_undocumented == true or (desc ~= "" and not live.lhs:find "^<Plug>")
    local home
    for _, i in ipairs(order) do
      local fh = filesets[i] and filesets[i][live.mode .. live.lhs]
      if (visible or fh) and match.section(sections[i], m, origin, fh ~= nil) then
        home = i
        items[i] = items[i] or {}
        table.insert(items[i], {
          modes = { live.mode },
          lhs = m.lhs,
          desc = desc,
          group = fh and fh.group or origin.group,
          order = fh and fh.order or origin.order,
          plugin = origin.plugin,
        })
        break
      end
    end
    if not home and visible and not has_rest then
      local other = #sections + 1
      items[other] = items[other] or {}
      table.insert(items[other], {
        modes = { live.mode },
        lhs = m.lhs,
        desc = desc,
        group = origin.group,
        order = origin.order,
        plugin = origin.plugin,
      })
    end
  end
  return items
end

local function section_state(id, s, items, wk_groups)
  local groups = group.build(group.merge(items or {}), s.group_by or "none", wk_groups)
  local count = 0
  for _, g in ipairs(groups) do
    count = count + #g.rows
  end
  return {
    id = id,
    title = s.title,
    subtitle = s.subtitle,
    groups = groups,
    count = count,
    collapsed = s.collapsed == true,
  }
end

--- @param cfg KeymapHelperConfig
--- @param data KeymapHelperData
--- @param normalize fun(lhs: string): string
--- @param display fun(lhs: string): string
--- @param env { mapleader: string|nil, maplocalleader: string|nil }|nil leader values; nil = no intro
--- @return KeymapHelperState
function M.build(cfg, data, normalize, display, env)
  local items = assign(cfg, data, normalize, display)
  local wk_groups = data.wk_groups or {}

  local sections = {}
  for i, s in ipairs(cfg.sections) do
    if not s.hidden then
      table.insert(sections, section_state(i, s, items[i], wk_groups))
    end
  end
  local other = #cfg.sections + 1
  if items[other] then
    local implicit = { title = "Other", rest = true, collapsed = true }
    table.insert(sections, section_state(other, implicit, items[other], wk_groups))
  end

  local intro
  if env and cfg.intro and cfg.intro.enabled then
    intro = require("keymap-helper.intro").build(env.mapleader, env.maplocalleader)
  end

  return {
    sections = sections,
    footer = cfg.window.footer,
    intro = intro,
    intro_collapsed = intro ~= nil and cfg.intro.collapsed == true,
  }
end

--- Starting view: every section folded as the config asks.
--- @param state KeymapHelperState
--- @return KeymapHelperView
function M.initial_view(state)
  local collapsed = {}
  for _, s in ipairs(state.sections) do
    collapsed[s.id] = s.collapsed == true
  end
  if state.intro then
    collapsed.intro = state.intro_collapsed == true
  end
  return { collapsed = collapsed }
end

--- Pure reducer: returns a new view, never touches the input.
--- @param view KeymapHelperView
--- @param action KeymapHelperAction
--- @return KeymapHelperView
function M.reduce(view, action)
  local collapsed = vim.deepcopy(view.collapsed)
  local t, id = action.type, action.id
  if t == "open_all" or t == "close_all" then
    for k in pairs(collapsed) do
      collapsed[k] = t == "close_all"
    end
  elseif collapsed[id] ~= nil then
    if t == "toggle" then
      collapsed[id] = not collapsed[id]
    elseif t == "open" then
      collapsed[id] = false
    elseif t == "close" then
      collapsed[id] = true
    end
  end
  return { collapsed = collapsed }
end

return M
