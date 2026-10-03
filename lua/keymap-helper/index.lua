--- Text index of the user's config: which file (and under which header, in
--- what order) each string-written map(...) call sits. Lowest-priority origin
--- evidence, used when nothing exact (track, callback, sid) is available.
local M = {}

local scan = require "keymap-helper.scan"

--- @class KeymapHelperIndexEntry
--- @field file string
--- @field group string|nil box-header text; nil before the first header
--- @field order integer 1-based running position across all files

--- @alias KeymapHelperIndex table<string, KeymapHelperIndexEntry> mode .. canonical lhs

local SKIP_DIRS = { [".git"] = true, node_modules = true, pack = true }
local MAX_DEPTH = 8

-- path -> { stamp = "sec:nsec:size", entries = KeymapHelperScanEntry[] }
local cache = {}

--- Sorted absolute paths of *.lua under `dir`, at most `max_files`.
--- @param dir string
--- @param max_files integer
--- @return string[] paths, boolean capped
function M.list_files(dir, max_files)
  if not vim.uv.fs_stat(dir) then
    return {}, false
  end
  local all = {}
  local ok = pcall(function()
    for name, kind in
      vim.fs.dir(dir, {
        depth = MAX_DEPTH,
        skip = function(d)
          return not SKIP_DIRS[vim.fs.basename(d)]
        end,
      })
    do
      if kind == "file" and name:match "%.lua$" then
        table.insert(all, dir .. "/" .. name)
      end
    end
  end)
  if not ok then
    return {}, false
  end
  table.sort(all)
  local out = {}
  for i = 1, math.min(#all, max_files) do
    out[i] = all[i]
  end
  return out, #all > max_files
end

--- @param parsed { file: string, entries: KeymapHelperScanEntry[] }[]
--- @param normalize fun(lhs: string): string
--- @return KeymapHelperIndex
function M.from_parsed(parsed, normalize)
  local out, order = {}, 0
  for _, f in ipairs(parsed) do
    for _, e in ipairs(f.entries) do
      order = order + 1
      local key = normalize(e.lhs)
      for mode in e.modes:gmatch "[^,]+" do
        if out[mode .. key] == nil then
          out[mode .. key] = {
            file = f.file,
            group = e.group ~= "" and e.group or nil,
            order = order,
          }
        end
      end
    end
  end
  return out
end

local function parse_cached(path, opts)
  local st = vim.uv.fs_stat(path)
  if not st then
    return nil
  end
  local stamp = ("%s:%s:%s"):format(st.mtime.sec, st.mtime.nsec, st.size)
  local hit = cache[path]
  if hit and hit.stamp == stamp then
    return hit.entries
  end
  local lines = scan.read_lines(path)
  if not lines then
    return nil
  end
  local entries = scan.parse(lines, {
    header_pattern = opts.header_pattern,
    map_functions = opts.map_functions,
    fallback_group = "",
  })
  cache[path] = { stamp = stamp, entries = entries }
  return entries
end

--- @param dir string
--- @param opts { header_pattern: string, map_functions: string[], max_files: integer }
--- @param normalize fun(lhs: string): string
--- @return KeymapHelperIndex index, { files: integer, capped: boolean } stats
function M.build(dir, opts, normalize)
  local paths, capped = M.list_files(dir, opts.max_files)
  local parsed = {}
  for _, p in ipairs(paths) do
    local entries = parse_cached(p, opts)
    if entries then
      table.insert(parsed, { file = p, entries = entries })
    end
  end
  return M.from_parsed(parsed, normalize), { files = #paths, capped = capped }
end

return M
