--- :KeymapHelper <sub> [args] dispatcher and its completion.
--- A bare :KeymapHelper opens the list.
local M = {}

--- @type table<string, fun(args: string[], bang: boolean)>
M.subcommands = {
  show = function()
    require("keymap-helper").show()
  end,
  hint = function()
    require("keymap-helper").hint()
  end,
  health = function()
    vim.cmd "checkhealth keymap-helper"
  end,
}

--- @param fargs string[]
--- @param bang boolean
function M.dispatch(fargs, bang)
  local sub = fargs[1] or "show"
  local fn = M.subcommands[sub]
  if not fn then
    local names = vim.tbl_keys(M.subcommands)
    table.sort(names)
    vim.notify(
      ("keymap-helper: unknown subcommand %q (have: %s)"):format(tostring(sub), table.concat(names, ", ")),
      vim.log.levels.ERROR
    )
    return
  end
  fn(vim.list_slice(fargs, 2), bang)
end

--- @return string[]
function M.complete(arglead, cmdline, _)
  local words = vim.split(cmdline, "%s+")
  if #words > 2 then
    return {}
  end
  local names = vim.tbl_keys(M.subcommands)
  table.sort(names)
  return vim.tbl_filter(function(n)
    return vim.startswith(n, arglead)
  end, names)
end

return M
