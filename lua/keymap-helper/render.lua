--- Pure renderer: state in, buffer lines + highlight spans + hit regions out.
---
--- Spans and regions use 0-based rows and byte columns (what extmarks and
--- getmousepos() use), so the window layer applies them without converting.
local M = {}

M.ROW_FORMAT = "    %-5s %-22s %s"

--- @class KeymapHelperSpan
--- @field row integer
--- @field col_start integer
--- @field col_end integer -1 = end of line
--- @field hl string

--- @class KeymapHelperRegion
--- @field row integer
--- @field kind string
--- @field id integer|string

--- @class KeymapHelperRender
--- @field lines string[]
--- @field spans KeymapHelperSpan[]
--- @field regions KeymapHelperRegion[]

--- @param state KeymapHelperState
--- @return KeymapHelperRender
function M.render(state)
  local lines, spans, regions = {}, {}, {}

  local function add(text, hl)
    table.insert(lines, text)
    if hl then
      table.insert(spans, { row = #lines - 1, col_start = 0, col_end = -1, hl = hl })
    end
  end

  for i, section in ipairs(state.sections) do
    if i > 1 then
      add ""
    end
    local title = "  " .. section.title
    add(section.subtitle and (title .. "  ·  " .. section.subtitle) or title, "KeymapHelperSection")
    table.insert(regions, { row = #lines - 1, kind = "section", id = section.id })

    for _, group in ipairs(section.groups) do
      if group.title then
        add ""
        add("  " .. group.title, "KeymapHelperGroup")
      end
      for _, row in ipairs(group.rows) do
        add(M.ROW_FORMAT:format(row.modes, row.lhs, row.desc))
      end
    end
  end

  if state.footer and state.footer ~= "" then
    add ""
    add("  " .. state.footer, "KeymapHelperFooter")
  end

  return { lines = lines, spans = spans, regions = regions }
end

return M
