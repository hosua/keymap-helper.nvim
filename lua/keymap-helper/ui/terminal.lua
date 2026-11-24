--- A command running in a terminal inside a popup.nvim float. The float and
--- its geometry come from popup.nvim; this only starts the job in its buffer
--- and closes the float when the job ends.
local float = require "popup.float"
local geometry = require "popup.geometry"

local M = {}

--- @param opts { cmd: string[], title: string, env: table<string,string>|nil, on_exit: fun(code: integer)|nil }
--- @return PopupFloat
function M.open(opts)
  local function rect()
    return geometry.fractional(geometry.env(), 0.92, 0.92)
  end
  local f = float.open {
    rect = rect(),
    title = " " .. opts.title .. " ",
    filetype = "keymap-helper-edit",
    zindex = 60,
    wo = { winfixbuf = true },
  }
  local job_opts = {
    env = opts.env,
    on_exit = function(_, code)
      vim.schedule(function()
        float.close(f)
        if opts.on_exit then
          opts.on_exit(code)
        end
      end)
    end,
  }
  if vim.fn.has "nvim-0.11" == 1 then
    job_opts.term = true
    vim.fn.jobstart(opts.cmd, job_opts)
  else
    vim.fn.termopen(opts.cmd, job_opts)
  end
  float.on_resize(f, function()
    float.configure(f, rect(), " " .. opts.title .. " ")
  end)
  vim.cmd "startinsert"
  return f
end

return M
