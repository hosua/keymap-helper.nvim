--- :KeymapHelper <sub> [args] dispatcher and its completion.
--- A bare :KeymapHelper opens the list.
local M = {}

--- Fit a confirm message to the popup: paths shortened (relative to `root`,
--- else with ~), words wrapped to `width` display columns. A word wider than
--- the popup (a long path) keeps its tail behind an ellipsis.
--- @param message string
--- @param width integer
--- @param root string|nil
--- @return string[]
function M.wrap(message, width, root)
  local home = vim.uv.os_homedir()
  local function short(line)
    if root and root ~= "" then
      line = line:gsub(vim.pesc((root:gsub("/+$", "")) .. "/"), "")
    end
    if home and home ~= "" then
      line = line:gsub(vim.pesc(home) .. "/", "~/")
    end
    return line
  end
  local function fit(word, width)
    if vim.fn.strdisplaywidth(word) <= width then
      return word
    end
    local chars = vim.fn.strchars(word)
    local keep = chars - 1
    while keep > 0 and vim.fn.strdisplaywidth("…" .. vim.fn.strcharpart(word, chars - keep)) > width do
      keep = keep - 1
    end
    return "…" .. vim.fn.strcharpart(word, chars - keep)
  end
  local out = {}
  for _, raw in ipairs(vim.split(message, "\n", { plain = true })) do
    local line = short(raw)
    local indent = line:match "^%s*"
    local cur = indent
    for word in line:gmatch "%S+" do
      word = fit(word, width - vim.fn.strdisplaywidth(indent))
      local sep = (cur == indent) and "" or " "
      if vim.fn.strdisplaywidth(cur .. sep .. word) > width and cur ~= indent then
        out[#out + 1] = cur
        cur = indent .. word
      else
        cur = cur .. sep .. word
      end
    end
    out[#out + 1] = cur
  end
  return out
end

--- Yes/no question in a popup.nvim float. `:KeymapHelper import!` and
--- `generate!` skip it.
--- @param message string
--- @return boolean
local function confirm(message)
  local width = math.max(30, math.min(70, vim.o.columns - 10))
  local lines = M.wrap(message, width, vim.fn.stdpath "config")
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
M.subargs = { import = { "drop_headers", "keep_headers" }, generate = { "check" } }

--- @type table<string, fun(args: string[], bang: boolean)>
M.subcommands = {
  import = function(args, bang)
    local opts = { confirm = not bang and confirm or function()
      return true
    end }
    for _, a in ipairs(args) do
      if a == "drop_headers" then
        opts.drop_headers = true
      elseif a ~= "keep_headers" then -- the default, accepted for old habits
        return vim.notify(("keymap-helper: import takes drop_headers, not %q"):format(a), vim.log.levels.ERROR)
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
  edit = function()
    require("keymap-helper.tui").edit()
  end,
  show = function()
    require("keymap-helper").show()
  end,
  close = function()
    if not require("keymap-helper").close() then
      vim.notify "keymap-helper: no keymap list is open"
    end
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
