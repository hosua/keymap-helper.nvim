-- The keymap list is modal: focus comes straight back unless the user
-- presses q. Specs drive real windows in the headless nvim.
local fl = require "keymap-helper.ui.float"
local model = require "keymap-helper.model"
local keys = require "keymap-helper.ui.keys"
local commands = require "keymap-helper.commands"

vim.cmd "runtime plugin/keymap-helper.lua"

local function open()
  local state = { sections = {}, footer = keys.footer() }
  return fl.open_list(state, model.initial_view(state), { title = "t", max_width = 40 })
end

-- The pull-back runs through vim.schedule; wait for it.
local function settle()
  vim.wait(200, function()
    return false
  end)
end

local function groups()
  local n = 0
  for _, a in ipairs(vim.api.nvim_get_autocmds { event = { "WinLeave", "WinEnter" } }) do
    if (a.group_name or ""):find "^KeymapHelperModal" then
      n = n + 1
    end
  end
  return n
end

local function reset()
  pcall(fl.close_list)
  vim.cmd "silent! only!"
  vim.cmd "silent! %bwipeout!"
end

describe("modal list", function()
  it("keeps focus on every route that tries to leave", function()
    reset()
    local base = vim.api.nvim_get_current_win()
    vim.cmd "vsplit"
    local other = vim.api.nvim_get_current_win()
    local win = open()
    local routes = {
      function()
        vim.api.nvim_set_current_win(other)
      end,
      function()
        vim.cmd "wincmd w"
      end,
      function()
        vim.cmd "wincmd p"
      end,
      function()
        vim.cmd "wincmd h"
      end,
      function()
        vim.cmd("buffer " .. vim.api.nvim_win_get_buf(base))
      end,
      function()
        vim.cmd "split"
      end,
    }
    for i, route in ipairs(routes) do
      pcall(route)
      settle()
      eq(win, vim.api.nvim_get_current_win(), "route " .. i)
    end
    reset()
  end)

  it("closes on q only, and drops the autocmds", function()
    reset()
    local win, buf = open()
    eq(1, groups() > 0 and 1 or 0)
    local bound = {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      bound[m.lhs] = true
    end
    ok(not bound["<Esc>"], "<Esc> must not be bound")
    vim.api.nvim_feedkeys("q", "x", false)
    ok(not vim.api.nvim_win_is_valid(win))
    eq(0, groups())
  end)

  it("cleans up when the window dies some other way", function()
    reset()
    local win = open()
    vim.api.nvim_win_close(win, true)
    eq(0, groups())
    reset()
    open()
    vim.cmd "close"
    settle()
    eq(0, groups())
    reset()
  end)

  it("lets a keymap-helper float take focus and returns when it closes", function()
    reset()
    local win = open()
    local popup = require "popup.float"
    local f = popup.open { rect = { row = 1, col = 1, width = 20, height = 3 }, lines = { "x" } }
    settle()
    eq(f.win, vim.api.nvim_get_current_win())
    popup.close(f)
    settle()
    eq(win, vim.api.nvim_get_current_win())
    reset()
  end)

  it("exempts the editor terminal and returns to the list after it closes", function()
    reset()
    local win = open()
    local t = require("keymap-helper.ui.terminal").open { cmd = { "sh", "-c", "sleep 0.3" }, title = "x" }
    settle()
    eq(t.win, vim.api.nvim_get_current_win())
    vim.wait(2000, function()
      return not vim.api.nvim_win_is_valid(t.win)
    end)
    settle()
    eq(win, vim.api.nvim_get_current_win())
    reset()
  end)

  it("a second show only refocuses", function()
    reset()
    local win = open()
    local before = #vim.api.nvim_list_wins()
    eq(win, fl.focus_list())
    eq(before, #vim.api.nvim_list_wins())
    reset()
    eq(nil, fl.focus_list())
  end)

  it(":KeymapHelper close closes it from anywhere", function()
    reset()
    local win = open()
    local f = require("popup.float").open { rect = { row = 1, col = 1, width = 20, height = 3 }, lines = { "x" } }
    vim.cmd "KeymapHelper close"
    ok(not vim.api.nvim_win_is_valid(win))
    eq(0, groups())
    require("popup.float").close(f)
    ok(vim.tbl_contains(commands.complete("cl", "KeymapHelper cl", 0), "close"))
    reset()
  end)
end)
