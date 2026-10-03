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
--- @field origin KeymapHelperOrigin|nil set by model.gather

-- Map modes that also answer for narrower queries: nvim_get_keymap("v")
-- returns v, x and s maps, "" returns n/v/x/s/o maps, "!" returns i and c.
M.COVERS = { [" "] = "nvxso", v = "vxs", ["!"] = "ic" }

--- The mode a map was actually defined for, given the mode that was queried.
--- nil = the map is narrower than the query and is only wanted under its own mode.
--- @param map_mode string the `mode` field nvim reports for the map
--- @param query string mode passed to nvim_get_keymap
--- @param want table<string, boolean> every mode being queried
--- @return string|nil
function M.own_mode(map_mode, query, want)
  if map_mode == query then
    return query
  end
  -- Partial masks such as "nox" (:map then :sunmap) or "nv" have no COVERS
  -- entry: they answer for each letter they contain.
  local covers = M.COVERS[map_mode] or (#map_mode > 1 and map_mode or nil)
  if covers and covers:find(query, 1, true) then
    return want[map_mode] and map_mode or query
  end
  return want[map_mode] and map_mode or nil
end

--- Global mappings for the given modes, each reported once under its own mode.
--- @param modes string[]
--- @return KeymapHelperLiveMap[]
function M.live(modes)
  local want = {}
  for _, mode in ipairs(modes) do
    want[mode] = true
  end
  local out, seen = {}, {}
  for _, mode in ipairs(modes) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local own = M.own_mode(m.mode, mode, want)
      local lhs = vim.fn.keytrans(m.lhsraw or vim.keycode(m.lhs))
      if own and not seen[own .. lhs] then
        seen[own .. lhs] = true
        table.insert(out, {
          mode = own,
          lhs = lhs,
          desc = m.desc,
          rhs = m.rhs,
          callback = m.callback,
          sid = m.sid,
          lnum = m.lnum,
        })
      end
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
