--- Timestamped backups next to the file they protect. A backup is never
--- overwritten: a name that is taken gets a numeric suffix.
---
---   lua/mappings.lua  ->  lua/mappings_2026_11_24_09:15:02.bak
---   (same second)     ->  lua/mappings_2026_11_24_09:15:02_1.bak
local Path = require "plenary.path"

local M = {}

M.STAMP_FORMAT = "%Y_%m_%d_%H:%M:%S"

--- File name without its last extension: mappings.lua -> mappings.
--- @param path string
--- @return string
function M.stem(path)
  local base = vim.fs.basename(path)
  return (base:gsub("%.[^.]*$", ""))
end

--- @param now integer|nil epoch seconds
--- @return string local time, e.g. 2026_11_24_09:15:02
function M.stamp(now)
  return os.date(M.STAMP_FORMAT, now or os.time())
end

--- First free backup path for `target`.
--- @param target string
--- @param now integer|nil
--- @param taken fun(path: string): boolean|nil defaults to "exists on disk"
--- @return string
function M.path_for(target, now, taken)
  taken = taken or function(p)
    return Path:new(p):exists()
  end
  local dir = vim.fs.dirname(target)
  local base = ("%s/%s_%s"):format(dir, M.stem(target), M.stamp(now))
  local candidate = base .. ".bak"
  local n = 0
  while taken(candidate) do
    n = n + 1
    candidate = ("%s_%d.bak"):format(base, n)
  end
  return candidate
end

--- Copy `target` to a new backup file. Does nothing when `target` does not
--- exist yet. The copy refuses to replace an existing file, so two writers in
--- the same second still get two backups.
--- @param target string
--- @param now integer|nil
--- @return string|nil path backup written, nil when there was nothing to back up
--- @return string|nil err
function M.create(target, now)
  if not Path:new(target):exists() then
    return nil
  end
  for _ = 1, 20 do
    local dest = M.path_for(target, now)
    local ok, err, name = vim.uv.fs_copyfile(target, dest, { excl = true })
    if ok then
      return dest
    end
    if name ~= "EEXIST" then
      return nil, ("could not back up %s to %s: %s"):format(target, dest, tostring(err))
    end
  end
  return nil, "could not find a free backup name for " .. target
end

--- Backups of `target`, newest first. Names sort by time because the stamp
--- is year-first and zero-padded.
--- @param target string
--- @return string[]
function M.list(target)
  local scandir = require "plenary.scandir"
  local dir = vim.fs.dirname(target)
  local prefix = M.stem(target) .. "_"
  local found = {}
  for _, p in ipairs(scandir.scan_dir(dir, { depth = 1, add_dirs = false, search_pattern = "%.bak$" })) do
    local name = vim.fs.basename(p)
    if vim.startswith(name, prefix) and name:match "^.-_%d%d%d%d_%d%d_%d%d_%d%d:%d%d:%d%d" then
      found[#found + 1] = p
    end
  end
  table.sort(found, function(a, b)
    return a > b
  end)
  return found
end

return M
