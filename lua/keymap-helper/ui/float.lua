--- The only module that opens windows: the keymap list float and the
--- startup hint toast.
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

--- Scrollable, focused float holding the rendered list.
--- @param r KeymapHelperRender
--- @param opts { title: string, max_width: integer }
--- @return integer win, integer buf
function M.open_list(r, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "keymap-helper"
  paint(buf, r)

  local width = math.max(20, math.min(opts.max_width, vim.o.columns - 6))
  local height = math.max(1, math.min(#r.lines, vim.o.lines - 8))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = opts.title,
    title_pos = "center",
  })
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false

  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true, desc = "close keymap list" })
  end

  return win, buf
end

--- Non-focusable, self-closing hint. Closes on the first cursor movement,
--- insert, or buffer switch, so `nvim some-file` is never interrupted.
--- @param text string[]
--- @param opts { timeout_ms: integer }
--- @return integer win
function M.toast(text, opts)
  local width = 0
  for _, l in ipairs(text) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width, vim.o.columns - 4)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = #text,
    row = math.max(0, vim.o.lines - #text - 4),
    col = math.max(0, vim.o.columns - width - 3),
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
