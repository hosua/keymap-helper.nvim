--- `:KeymapHelper edit`: the terminal UI (tui/) in a floating terminal.
---
--- The live nvim hands the UI an analysis snapshot through a temp file
--- (template/live.lua), so the UI does not start a scratch nvim. When the
--- snapshot cannot be built the UI falls back to `kh-template analyze`.
local M = {}

--- @return string
function M.plugin_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
end

--- The command line that starts the UI. Pure.
--- @param o { bun: string, plugin_root: string, root: string, template: string|nil, analysis: string|nil, result: string|nil }
--- @return string[]
function M.argv(o)
  local cmd = { o.bun, "run", o.plugin_root .. "/tui/src/index.tsx", "--root=" .. o.root }
  if o.template then
    cmd[#cmd + 1] = "--template=" .. o.template
  end
  if o.analysis then
    cmd[#cmd + 1] = "--analysis=" .. o.analysis
  end
  if o.result then
    cmd[#cmd + 1] = "--result=" .. o.result
  end
  return cmd
end

local function say(title, lines, danger)
  local chunks = vim.tbl_map(function(l)
    return { { l } }
  end, lines)
  require("popup.confirm").open {
    title = title,
    danger = danger,
    lines = chunks,
    choices = { { key = "q", label = "close" } },
    on_choice = function() end,
  }
end

--- @param opts { bun: string|nil, root: string|nil }|nil
function M.edit(opts)
  opts = opts or {}
  local bun = opts.bun or vim.fn.exepath "bun"
  if bun == "" then
    return say("keymap-helper", {
      "bun is not on your PATH.",
      "The editor is a terminal app that runs on bun.",
      "Install it from https://bun.sh, then run :KeymapHelper edit again.",
    }, true)
  end
  local plugin_root = M.plugin_root()
  if vim.fn.isdirectory(plugin_root .. "/tui/node_modules") == 0 then
    return say("keymap-helper", {
      "The editor's dependencies are not installed.",
      "Run once:  cd " .. plugin_root .. "/tui && bun install",
    }, true)
  end
  local cfg = require("keymap-helper.config").get()
  local root = (opts.root or vim.fn.stdpath "config"):gsub("/+$", "")
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local analysis
  local ok, snap = pcall(require("keymap-helper.template.live").snapshot)
  if ok then
    analysis = tmp .. "/analysis.json"
    vim.fn.writefile({ vim.json.encode(snap) }, analysis)
  end
  local result = tmp .. "/result.json"
  local cmd = M.argv {
    bun = bun,
    plugin_root = plugin_root,
    root = root,
    template = cfg.template.path,
    analysis = analysis,
    result = result,
  }
  require("keymap-helper.ui.terminal").open {
    cmd = cmd,
    title = "keymap-helper edit",
    on_exit = function(code)
      local saved = false
      local fh = io.open(result, "r")
      if fh then
        local text = fh:read "*a"
        fh:close()
        local decoded, d = pcall(vim.json.decode, text)
        saved = decoded and type(d) == "table" and d.saved == true
      end
      vim.fn.delete(tmp, "rf")
      if code ~= 0 then
        vim.notify(("keymap-helper: the editor exited with code %d"):format(code), vim.log.levels.ERROR)
      elseif saved then
        vim.notify(
          "keymap-helper: the template and the mappings file were saved. Restart nvim to load them "
            .. "(:source lua/mappings.lua re-applies maps but keeps ones you deleted).",
          vim.log.levels.WARN
        )
      end
    end,
  }
end

return M
