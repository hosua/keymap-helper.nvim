--- Highlight groups, linked with default=true so a theme or the user wins.
--- Re-applied on every open: NvChad's base46 swaps themes without firing
--- ColorScheme, which would otherwise leave the links cleared.
local M = {}

M.LINKS = {
  KeymapHelperSection = "Type",
  KeymapHelperGroup = "Title",
  KeymapHelperFooter = "Comment",
  KeymapHelperHintBorder = "DiagnosticInfo",
}

function M.apply()
  for name, target in pairs(M.LINKS) do
    vim.api.nvim_set_hl(0, name, { link = target, default = true })
  end
end

return M
