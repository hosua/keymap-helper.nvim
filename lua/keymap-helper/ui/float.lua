--- The only module that opens windows: the keymap list and the startup hint,
--- both on popup.nvim's float layer.
local float = require "popup.float"
local geometry = require "popup.geometry"

local M = {}

local NS = vim.api.nvim_create_namespace "keymap_helper"

--- @param r KeymapHelperRender
--- @param max_width integer
local function rect_for(r, max_width)
  return geometry.list(geometry.env(), max_width, #r.lines)
end

--- Scrollable, focused float holding the rendered list. Owns the fold
--- state: every toggle re-renders, repaints and resizes the window.
--- @param state KeymapHelperState
--- @param view KeymapHelperView
--- @param opts { title: string, max_width: integer }
--- @return integer win, integer buf
function M.open_list(state, view, opts)
  local render = require "keymap-helper.render"
  local model = require "keymap-helper.model"
  local r = render.render(state, view)

  local rect = rect_for(r, opts.max_width)
  -- winhl keeps the list on the theme's own float groups instead of popup's
  -- Popup* links. "EndOfBuffer:" is what style = "minimal" sets itself, and
  -- an explicit winhl replaces it.
  local f = float.open {
    rect = rect,
    lines = r.lines,
    spans = r.spans,
    ns = NS,
    title = opts.title,
    title_pos = "center",
    border = "rounded",
    filetype = "keymap-helper",
    winhl = "EndOfBuffer:",
    wo = { cursorline = true },
  }
  local win, buf = f.win, f.buf

  --- Apply an action, repaint, resize, and park the cursor on `id`'s header.
  --- @param action KeymapHelperAction
  --- @param id integer|string|nil section to keep the cursor on
  local function apply(action, id)
    view = model.reduce(view, action)
    r = render.render(state, view)
    float.paint(f, r)
    -- The width stays what it was at open and the column follows that width;
    -- only the height and the row are recomputed.
    local next_rect = rect_for(r, opts.max_width)
    next_rect.width = rect.width
    next_rect.col = math.max(0, math.floor((vim.o.columns - rect.width) / 2))
    float.configure(f, next_rect, opts.title, nil, { title_pos = "center" })
    local row = id and render.row_of(r, id) or 0
    vim.api.nvim_win_set_cursor(win, { math.min(row + 1, #r.lines), 0 })
  end

  local function cursor_section()
    return render.section_at(r, vim.api.nvim_win_get_cursor(win)[1] - 1)
  end

  local function bind(keys, desc, action_type)
    for _, key in ipairs(keys) do
      vim.keymap.set("n", key, function()
        local id = cursor_section()
        if id then
          apply({ type = action_type, id = id }, id)
        end
      end, { buffer = buf, nowait = true, silent = true, desc = desc })
    end
  end
  local A = require("keymap-helper.ui.keys").ACTIONS
  bind(A.toggle.keys, A.toggle.desc, "toggle")
  bind(A.open.keys, A.open.desc, "open")
  bind(A.close.keys, A.close.desc, "close")

  for name, key in pairs { open_all = "open_all", close_all = "close_all" } do
    for _, lhs in ipairs(A[name].keys) do
      vim.keymap.set("n", lhs, function()
        apply({ type = key }, cursor_section())
      end, { buffer = buf, nowait = true, silent = true, desc = A[name].desc })
    end
  end

  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == win then
      for _, region in ipairs(r.regions) do
        if region.kind == "section" and region.row == pos.line - 1 then
          apply({ type = "toggle", id = region.id }, region.id)
          return
        end
      end
    end
    -- Anything but a header click (including a click in another window,
    -- since this map is live whenever the list buffer is current) gets the
    -- built-in behaviour; "n" keeps this map from catching it again.
    vim.api.nvim_feedkeys(vim.keycode "<LeftMouse>", "n", false)
  end, { buffer = buf, nowait = true, silent = true, desc = "toggle section / click" })

  for _, key in ipairs(A.quit.keys) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true, desc = A.quit.desc })
  end

  return win, buf
end

--- Non-focusable, self-closing hint (popup.float.toast).
--- @param lines string[]
--- @param opts { timeout_ms: integer, position: "center"|"bottom_right"|nil }
--- @return integer win
function M.toast(lines, opts)
  return float.toast(lines, {
    timeout_ms = opts.timeout_ms,
    position = opts.position,
    border = "rounded",
    winhl = "FloatBorder:KeymapHelperHintBorder",
  })
end

return M
