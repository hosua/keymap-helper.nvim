--- One-line summaries of an import or generate result, shared by the
--- command (vim.notify) and the scripts (stdout).
local M = {}

local function short(path, root)
  if root and vim.startswith(path, root:gsub("/+$", "") .. "/") then
    return path:sub(#root:gsub("/+$", "") + 2)
  end
  return vim.fn.fnamemodify(path, ":~")
end

--- @param cmd string "import"|"generate"
--- @param res table result from keymap-helper.template
--- @param root string|nil paths under it print relative
--- @return string
function M.line(cmd, res, root)
  root = root or vim.fn.stdpath "config"
  if cmd == "import" then
    if res.status == "in_sync" then
      return ("%s already generates the mappings file, nothing to import"):format(short(res.template, root))
    end
    local s = ("imported %d maps and %d raw blocks into %s"):format(res.maps, res.raw, short(res.template, root))
    if res.backup then
      s = s .. (" (old template saved as %s)"):format(short(res.backup, root))
    end
    return s
  end
  if res.status == "unchanged" then
    return ("%s already matches the template, nothing written"):format(short(res.target, root))
  end
  local s = ("wrote %s"):format(short(res.target, root))
  if res.backup then
    s = s .. (" (backup: %s)"):format(short(res.backup, root))
  end
  return s
end

return M
