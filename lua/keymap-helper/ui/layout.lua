--- Pure geometry for the startup hint toast. No vim.api calls, so it is
--- unit-testable without a UI.
local M = {}

-- The rounded border adds one cell on every side of the window content.
local BORDER = 2
-- Cells kept free around the toast when it is clamped to a small editor.
local MARGIN = 4

--- @class KeymapHelperToastGeometry
--- @field row integer top-left of the window content, editor-relative
--- @field col integer
--- @field width integer
--- @field height integer

--- @param content_width integer
--- @param content_height integer
--- @param editor_columns integer
--- @param editor_lines integer
--- @param position "center"|"bottom_right"|nil unknown values fall back to "center"
--- @return KeymapHelperToastGeometry
function M.toast(content_width, content_height, editor_columns, editor_lines, position)
  local width = math.min(content_width, math.max(editor_columns - MARGIN, 1))
  local height = math.min(content_height, math.max(editor_lines - MARGIN, 1))

  local row, col
  if position == "bottom_right" then
    row = editor_lines - height - 4
    col = editor_columns - width - 3
  else
    row = math.floor((editor_lines - height - BORDER) / 2)
    col = math.floor((editor_columns - width - BORDER) / 2)
  end

  return { row = math.max(0, row), col = math.max(0, col), width = width, height = height }
end

return M
