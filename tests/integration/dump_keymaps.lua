-- Run by template_roundtrip_spec.lua in a child nvim: `nvim -l dump_keymaps.lua FILE`.
-- Loads FILE with every `require` that is not installed answered by a stub,
-- then prints one JSON line with the global keymaps it created.
-- The stub is a function so it is also a valid rhs when a file does
-- `map(..., require("x").make(fn))`. Indexing any function gives the stub back
-- (this child process is throwaway, so changing the function metatable is fine).
local stub
stub = function()
  return stub
end
debug.setmetatable(stub, {
  __index = function()
    return stub
  end,
})
table.insert(package.loaders or package.searchers, function()
  return function()
    return stub
  end
end)

vim.g.mapleader = " "
vim.g.maplocalleader = ","
dofile(arg[1])

local out = {}
for _, mode in ipairs { "n", "i", "x", "v", "s", "o", "c", "t", "l" } do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    out[#out + 1] = { mode, m.lhs, m.desc or "", m.callback and "<function>" or (m.rhs or "") }
  end
end
table.sort(out, function(a, b)
  return table.concat(a, "\0") < table.concat(b, "\0")
end)
io.stdout:write(vim.json.encode(out), "\n")
