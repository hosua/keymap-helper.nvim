--- Text scanner for files that set mappings with `map(...)`-style calls.
---
--- Pure: `parse` takes lines and returns entries, so it is tested on tables.
--- Reading is in `read_lines`. Scanning text (rather than asking nvim) is what
--- recovers the grouping a user wrote with section-header comments, and the
--- source file of mappings whose rhs is a string, which nvim does not record.
local M = {}

-- How far past a `map(` line to look for its `desc = "..."`. Multi-line calls
-- with a function body put desc on the closing line.
local DESC_LOOKAHEAD = 40

--- @class KeymapHelperScanEntry
--- @field group string header the call sits under (or the fallback)
--- @field modes string comma-separated, e.g. "n,x"
--- @field lhs string as written in the file, e.g. "<leader>ff"
--- @field desc string "" when the call has none

--- Patterns that match the start of a mapping call for each function name,
--- with the modes as either a "n" string or a { "n", "x" } table.
--- @param names string[]
local function call_patterns(names)
  local out = {}
  for _, name in ipairs(names) do
    local fn = vim.pesc(name)
    table.insert(out, { table_modes = "^%s*" .. fn .. "%(%s*(%b{})%s*,%s*[\"'](.-)[\"']" })
    table.insert(out, { string_modes = "^%s*" .. fn .. "%(%s*[\"']([%a!]*)[\"']%s*,%s*[\"'](.-)[\"']" })
  end
  return out
end

--- @param line string
--- @param patterns table
--- @return string|nil modes, string|nil lhs
local function match_call(line, patterns)
  for _, p in ipairs(patterns) do
    local modes, lhs = line:match(p.table_modes or p.string_modes)
    if modes then
      if p.table_modes then
        modes = modes:gsub("[{}\"'%s]", "")
      end
      return modes, lhs
    end
  end
end

--- @param lines string[]
--- @param opts { header_pattern: string, map_functions: string[], fallback_group: string }
--- @return KeymapHelperScanEntry[]
function M.parse(lines, opts)
  local patterns = call_patterns(opts.map_functions)
  local entries = {}
  local group = opts.fallback_group

  for i, line in ipairs(lines) do
    local header = line:match(opts.header_pattern)
    if header then
      group = header
    else
      local modes, lhs = match_call(line, patterns)
      if modes and lhs then
        -- desc may sit on this line or on the closing line of a multi-line
        -- call, but must not be picked up from the *next* call.
        local desc
        for j = i, math.min(i + DESC_LOOKAHEAD, #lines) do
          if j > i and match_call(lines[j], patterns) then
            break
          end
          desc = lines[j]:match 'desc%s*=%s*"(.-)"' or lines[j]:match "desc%s*=%s*'(.-)'"
          if desc then
            break
          end
        end
        table.insert(entries, { group = group, modes = modes, lhs = lhs, desc = desc or "" })
      end
    end
  end

  return entries
end

--- @param path string
--- @return string[]|nil lines, string|nil err
function M.read_lines(path)
  local fh, err = io.open(path, "r")
  if not fh then
    return nil, err
  end
  local lines = {}
  for line in fh:lines() do
    table.insert(lines, line)
  end
  fh:close()
  return lines
end

return M
