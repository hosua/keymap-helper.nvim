--- Pure renderer: state in, buffer lines + highlight spans + hit regions out.
---
--- Spans and regions use 0-based rows and byte columns (what extmarks and
--- getmousepos() use), so the window layer applies them without converting.
local M = {}

M.ROW_INDENT = 4
M.MODE_WIDTH = 5
M.LHS_WIDTH = 22
M.CHEVRON_OPEN = "▾"
M.CHEVRON_CLOSED = "▸"

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
--- @field body_end integer 0-based row of the last section line (-1 when empty)

--- Pad to a display width, so multibyte keys keep the columns straight.
local function pad(text, width)
  return text .. (" "):rep(math.max(0, width - vim.fn.strdisplaywidth(text)))
end

--- @param state KeymapHelperState
--- @param view KeymapHelperView|nil fold state; nil = each section's own `collapsed`
--- @return KeymapHelperRender
function M.render(state, view)
  local lines, spans, regions = {}, {}, {}

  local function add(text, hl)
    table.insert(lines, text)
    if hl then
      table.insert(spans, { row = #lines - 1, col_start = 0, col_end = -1, hl = hl })
    end
  end

  -- One keymap row: modes | key | description, each with its own highlight.
  local function add_row(row)
    local modes, lhs = pad(row.modes, M.MODE_WIDTH), pad(row.lhs, M.LHS_WIDTH)
    table.insert(lines, (" "):rep(M.ROW_INDENT) .. modes .. " " .. lhs .. " " .. row.desc)
    local r = #lines - 1
    local key_start = M.ROW_INDENT + #modes + 1
    local desc_start = key_start + #lhs + 1
    table.insert(
      spans,
      { row = r, col_start = M.ROW_INDENT, col_end = M.ROW_INDENT + #row.modes, hl = "KeymapHelperMode" }
    )
    table.insert(spans, { row = r, col_start = key_start, col_end = key_start + #row.lhs, hl = "KeymapHelperKey" })
    if row.desc ~= "" then
      table.insert(spans, { row = r, col_start = desc_start, col_end = -1, hl = "KeymapHelperDesc" })
    end
  end

  if state.intro then
    -- Folds like a section (id "intro"), so the same keys and clicks work on it.
    local folded = state.intro_collapsed == true
    if view and view.collapsed.intro ~= nil then
      folded = view.collapsed.intro
    end
    add(("  %s %s"):format(folded and M.CHEVRON_CLOSED or M.CHEVRON_OPEN, state.intro.title), "KeymapHelperSection")
    table.insert(regions, { row = #lines - 1, kind = "section", id = "intro" })
    for _, line in ipairs(not folded and state.intro.lines or {}) do
      add(line, "KeymapHelperIntro")
    end
    add ""
  end

  for i, section in ipairs(state.sections) do
    if i > 1 then
      add ""
    end
    local folded = section.collapsed
    if view and view.collapsed[section.id] ~= nil then
      folded = view.collapsed[section.id]
    end
    local chevron = folded and M.CHEVRON_CLOSED or M.CHEVRON_OPEN
    local title = ("  %s %s (%d)"):format(chevron, section.title, section.count)
    add(section.subtitle and (title .. "  ·  " .. section.subtitle) or title, "KeymapHelperSection")
    table.insert(regions, { row = #lines - 1, kind = "section", id = section.id })

    for _, group in ipairs(not folded and section.groups or {}) do
      if group.title then
        add ""
        add("  " .. group.title, "KeymapHelperGroup")
      end
      for _, row in ipairs(group.rows) do
        add_row(row)
      end
    end
  end

  -- Rows past this are the footer: no section owns them, so <CR> there
  -- does nothing instead of folding whichever section happens to be last.
  local body_end = #lines - 1

  if state.footer and state.footer ~= "" then
    add ""
    add("  " .. state.footer, "KeymapHelperFooter")
  end

  return { lines = lines, spans = spans, regions = regions, body_end = body_end }
end

--- Id of the section whose header is at or nearest above `row`; nil above
--- the first header and on the footer.
--- @param r KeymapHelperRender
--- @param row integer 0-based
--- @return integer|string|nil
function M.section_at(r, row)
  if r.body_end and row > r.body_end then
    return nil
  end
  local found
  for _, region in ipairs(r.regions) do
    if region.kind == "section" and region.row <= row then
      found = region.id
    end
  end
  return found
end

--- 0-based row of a section's header line.
--- @param r KeymapHelperRender
--- @param id integer|string
--- @return integer|nil
function M.row_of(r, id)
  for _, region in ipairs(r.regions) do
    if region.kind == "section" and region.id == id then
      return region.row
    end
  end
  return nil
end

return M
