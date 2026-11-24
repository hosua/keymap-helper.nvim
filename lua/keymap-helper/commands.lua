--- :KeymapHelper <sub> [args] dispatcher and its completion.
--- A bare :KeymapHelper opens the list.
local M = {}

--- Yes/no question in a popup.nvim float. `:KeymapHelper import!` and
--- `generate!` skip it.
--- @param message string
--- @return boolean
local function confirm(message)
  local lines = vim.split(message, "\n", { plain = true })
  lines[#lines + 1] = ""
  lines[#lines + 1] = "y / <CR> yes    n / q no"
  return require("popup.confirm").choose { title = "keymap-helper", lines = lines }
end

--- Run a template step and show its one-line result.
local function template_step(step, opts)
  local res, err = require("keymap-helper.template")[step](opts)
  if not res then
    vim.notify("keymap-helper: " .. err, vim.log.levels.ERROR)
    return
  end
  vim.notify("keymap-helper: " .. require("keymap-helper.template.report").line(step, res))
end

--- Words each subcommand takes after its name, for completion.
M.subargs = { import = { "keep_headers" }, generate = { "check" } }

--- @type table<string, fun(args: string[], bang: boolean)>
M.subcommands = {
  import = function(args, bang)
    local opts = { confirm = not bang and confirm or function()
      return true
    end }
    for _, a in ipairs(args) do
      if a == "keep_headers" then
        opts.keep_headers = true
      else
        return vim.notify(("keymap-helper: import takes keep_headers, not %q"):format(a), vim.log.levels.ERROR)
      end
    end
    template_step("import", opts)
  end,
  generate = function(args, bang)
    local opts = { confirm = not bang and confirm or function()
      return true
    end }
    if args[1] == "check" then
      local ok, reason = require("keymap-helper.template").check(opts)
      if ok then
        return vim.notify "keymap-helper: the mappings file matches the template"
      end
      return vim.notify("keymap-helper: " .. (reason or "out of sync"), vim.log.levels.WARN)
    elseif args[1] then
      return vim.notify(("keymap-helper: generate takes check, not %q"):format(args[1]), vim.log.levels.ERROR)
    end
    template_step("generate", opts)
  end,
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
  if #words > 3 then
    return {}
  end
  if #words == 3 then
    return vim.tbl_filter(function(n)
      return vim.startswith(n, arglead)
    end, M.subargs[words[2]] or {})
  end
  local names = vim.tbl_keys(M.subcommands)
  table.sort(names)
  return vim.tbl_filter(function(n)
    return vim.startswith(n, arglead)
  end, names)
end

return M
