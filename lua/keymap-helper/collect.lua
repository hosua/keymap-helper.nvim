--- Reads what nvim actually has mapped, and normalises keys so a mapping
--- written as "<leader>ff" in a file and reported as " ff" by nvim compare
--- equal.
local M = {}

--- Canonical form of a key sequence: "<C-h>", "<c-H>" and "\b" all become
--- "<C-H>", and "<leader>x" becomes the leader key followed by x. Uses the
--- current mapleader, so call it at display time, not at module load.
--- @param lhs string
--- @return string
function M.normalize(lhs)
  return vim.fn.keytrans(vim.keycode(lhs))
end

--- Readable form of a live mapping's lhs: canonical, with the leader key
--- shown as "<leader>" again.
--- @param lhs string
--- @return string
function M.display(lhs)
  local key = M.normalize(lhs)
  local leader = M.normalize(vim.g.mapleader or "\\")
  if leader ~= "" and vim.startswith(key, leader) and #key > #leader then
    return "<leader>" .. key:sub(#leader + 1)
  end
  return key
end

--- @class KeymapHelperLiveMap
--- @field mode string
--- @field lhs string canonical (see normalize)
--- @field desc string|nil
--- @field rhs string|nil
--- @field callback function|nil
--- @field sid integer|nil
--- @field lnum integer|nil

--- Global mappings for the given modes.
--- @param modes string[]
--- @return KeymapHelperLiveMap[]
function M.live(modes)
  local out = {}
  for _, mode in ipairs(modes) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      table.insert(out, {
        mode = mode,
        lhs = vim.fn.keytrans(m.lhsraw or vim.keycode(m.lhs)),
        desc = m.desc,
        rhs = m.rhs,
        callback = m.callback,
        sid = m.sid,
        lnum = m.lnum,
      })
    end
  end
  return out
end

--- The key the user bound to :KeymapHelper (show), for the startup hint.
--- @return string|nil
function M.command_key()
  for _, m in ipairs(vim.api.nvim_get_keymap "n") do
    local rhs = m.rhs or ""
    if rhs:match "KeymapHelper%s*<[Cc][Rr]>" or rhs:match "KeymapHelper show%s*<[Cc][Rr]>" then
      return vim.fn.keytrans(m.lhsraw or vim.keycode(m.lhs))
    end
  end
end

return M
