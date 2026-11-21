--- Intro header: the short "how to read this list" text shown above the
--- keymap sections. Pure: leader values come in as arguments.
local M = {}

M.TITLE = "How to read this list"

local LEADER_FORMAT = "    %-14s %-12s %s"

local STATIC_LINES = {
  "",
  "    Modes   n normal · i insert · v visual+select · x visual · s select",
  "            o operator-pending · t terminal · c command-line",
  "            n,x = several modes · ! = insert+command-line",
  "    Keys    <C-x> Ctrl+x · <M-x>/<A-x> Alt+x · <S-x> Shift+x · <CR> Enter · <BS> Backspace",
}

--- Human-readable form of a leader value.
--- @param key string|nil vim.g.mapleader / vim.g.maplocalleader
--- @return string
function M.describe_key(key)
  if key == nil then
    return "\\ (default)"
  end
  if key == " " then
    return "<Space>"
  end
  return vim.fn.keytrans(key)
end

--- @class KeymapHelperIntro
--- @field title string
--- @field lines string[]

--- @param mapleader string|nil
--- @param maplocalleader string|nil
--- @return KeymapHelperIntro
function M.build(mapleader, maplocalleader)
  local lines = {
    LEADER_FORMAT:format("<leader>", M.describe_key(mapleader), "prefix for most custom maps (vim.g.mapleader)"),
    LEADER_FORMAT:format(
      "<localleader>",
      M.describe_key(maplocalleader),
      "prefix for filetype-local maps (vim.g.maplocalleader)"
    ),
  }
  vim.list_extend(lines, STATIC_LINES)
  return { title = M.TITLE, lines = lines }
end

return M
