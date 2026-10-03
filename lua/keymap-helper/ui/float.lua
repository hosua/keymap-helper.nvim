--- The only module that opens windows: the keymap list float and the
--- startup hint toast.
local layout = require "keymap-helper.ui.layout"

local M = {}

local NS = vim.api.nvim_create_namespace "keymap_helper"

--- @param buf integer
--- @param r KeymapHelperRender
local function paint(buf, r)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, r.lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for _, s in ipairs(r.spans) do
    local opts = { hl_group = s.hl }
    if s.col_end == -1 then
      opts.end_row = s.row + 1
    else
      opts.end_col = s.col_end
    end
    vim.api.nvim_buf_set_extmark(buf, NS, s.row, s.col_start, opts)
  end
end

--- @param height integer
--- @param width integer
--- @return table
local function geometry(width, height)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  }
end

--- @param r KeymapHelperRender
--- @return integer
local function height_for(r)
  return math.max(1, math.min(#r.lines, vim.o.lines - 8))
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

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "keymap-helper"
  paint(buf, r)

  local width = math.max(20, math.min(opts.max_width, vim.o.columns - 6))
  local win = vim.api.nvim_open_win(
    buf,
    true,
    vim.tbl_extend("force", geometry(width, height_for(r)), {
      style = "minimal",
      border = "rounded",
      title = opts.title,
      title_pos = "center",
    })
  )
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false

  --- Apply an action, repaint, resize, and park the cursor on `id`'s header.
  --- @param action KeymapHelperAction
  --- @param id integer|string|nil section to keep the cursor on
  local function apply(action, id)
    view = model.reduce(view, action)
    r = render.render(state, view)
    paint(buf, r)
    vim.api.nvim_win_set_config(win, geometry(width, height_for(r)))
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

--- Non-focusable, self-closing hint. Closes on the first cursor movement,
--- insert, or buffer switch, so `nvim some-file` is never interrupted.
--- @param lines string[]
--- @param opts { timeout_ms: integer, position: "center"|"bottom_right"|nil }
--- @return integer win
function M.toast(lines, opts)
  -- A blank line above and below and two columns either side: a bare line
  -- of text against the border reads as cramped.
  local text = { "" }
  for _, line in ipairs(lines) do
    table.insert(text, "  " .. line .. "  ")
  end
  table.insert(text, "")

  local width = 0
  for _, l in ipairs(text) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  local geo = layout.toast(width, #text, vim.o.columns, vim.o.lines, opts.position)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = geo.width,
    height = geo.height,
    row = geo.row,
    col = geo.col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    noautocmd = true,
    zindex = 60,
  })
  vim.wo[win].winhighlight = "FloatBorder:KeymapHelperHintBorder"

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave", "WinScrolled" }, {
    once = true,
    callback = close,
  })
  vim.defer_fn(close, opts.timeout_ms)
  return win
end

return M
