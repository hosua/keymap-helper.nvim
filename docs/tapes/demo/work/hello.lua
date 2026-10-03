-- demo buffer: the list opens on top of this
local M = {}

function M.greet(name)
  return ("hello, %s"):format(name)
end

return M
