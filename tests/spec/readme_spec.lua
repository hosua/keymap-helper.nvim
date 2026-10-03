-- The README's configuration block is a copy of config.defaults: fail when
-- the two drift, and when the vimdoc stops generating tags.
local config = require "keymap-helper.config"

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h:h")

local function read(path)
  local fh = assert(io.open(root .. "/" .. path, "r"))
  local s = fh:read "*a"
  fh:close()
  return s
end

describe("README", function()
  it("documents exactly config.defaults", function()
    local block = read("README.md"):match "<!%-%- defaults:start %-%->%s*```lua\n(.-)```%s*<!%-%- defaults:end %-%->"
    ok(block, "defaults block not found")
    local captured
    local env = {
      require = function()
        return {
          setup = function(t)
            captured = t
          end,
        }
      end,
    }
    local chunk = assert(load(block, "README defaults", "t", env))
    chunk()
    eq(config.defaults, captured)
  end)

  it("lists every highlight group", function()
    local readme = read "README.md"
    for name in pairs(require("keymap-helper.highlights").LINKS) do
      ok(readme:find("`" .. name .. "`", 1, true), name .. " missing from README")
    end
  end)
end)

describe("doc/keymap-helper.txt", function()
  it("generates help tags", function()
    local dir = tmpdir()
    vim.fn.mkdir(dir .. "/doc", "p")
    vim.fn.writefile(vim.fn.readfile(root .. "/doc/keymap-helper.txt"), dir .. "/doc/keymap-helper.txt")
    vim.cmd("helptags " .. vim.fn.fnameescape(dir .. "/doc"))
    local tags = table.concat(vim.fn.readfile(dir .. "/doc/tags"), "\n")
    for _, tag in ipairs { "keymap-helper", ":KeymapHelper", "keymap-helper-sections", "keymap-helper-track" } do
      ok(tags:find(vim.pesc(tag) .. "\t"), "missing tag " .. tag)
    end
  end)
end)
