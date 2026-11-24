-- `analyze` against a throwaway config that looks like NvChad: a defaults file
-- (lua/nvchad/mappings.lua on the runtimepath) required by the user's
-- lua/mappings.lua, which overrides one default, deletes another and defines a
-- key twice. The scratch nvim is a real `nvim --headless` start of that config.
local data_dir = vim.fn.stdpath "data"
if data_dir == vim.fn.expand "~/.local/share/nvim" then
  error "refusing to run against the real data dir (use `make integration`)"
end

local template = require "keymap-helper.template"

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

local function fake_config()
  local root = tmpdir() .. "/nvim"
  write(root .. "/init.lua", {
    'vim.g.mapleader = " "',
    'vim.opt.rtp:append(vim.fn.stdpath("config") .. "/fake-nvchad")',
    'vim.schedule(function() require "mappings" end)',
  })
  write(root .. "/fake-nvchad/lua/nvchad/mappings.lua", {
    "local map = vim.keymap.set",
    'map("n", "<leader>h", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })',
    'map("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "vertical split" })',
    'map("n", "<leader>w", "<cmd>w<CR>", { desc = "write" })',
  })
  write(root .. "/lua/mappings.lua", {
    'require "nvchad.mappings"',
    "local map = vim.keymap.set",
    'vim.keymap.del("n", "<leader>v")',
    'map("n", "<leader>h", "<cmd>MyHelp<CR>", { desc = "my help" })',
    'map("n", "<leader>x", ":one<CR>", { desc = "one" })',
    'map("n", "<leader>x", ":two<CR>", { desc = "two" })',
    'map({ "n", "x" }, "<leader>q", ":quit<CR>")',
  })
  return root
end

local function find(res, mode, lhs)
  for _, k in ipairs(res.keys) do
    if k.mode == mode and k.lhs == lhs then
      return k
    end
  end
end

describe("template analyze: a fake NvChad config", function()
  it("finds the override, the duplicate and the removed default", function()
    local root = fake_config()
    assert(template.import { root = root })
    local tpl = assert(template.load(root .. "/lua/mappings.template.json"))
    local ids = {}
    for _, e in ipairs(tpl.entries) do
      if e.kind == "map" then
        ids[e.lhs .. ((e.opts or {}).desc or "")] = e.id
      end
    end

    local res, err = template.analyze { root = root, timeout = 60 }
    ok(res, err)
    eq("ok", res.status, res.error)
    eq("replay", res.source)
    eq(" ", res.leader)
    eq({ duplicates = 1, overrides = 1, removed = 1 }, res.counts)

    local help = assert(find(res, "n", "<Space>h"))
    ok(help.override)
    eq("default:nvchad", help.defs[1].source)
    eq("telescope help page", help.defs[1].desc)
    eq("Telescope help_tags", help.defs[1].summary)
    eq("template:" .. ids["<leader>hmy help"], help.defs[2].source)
    ok(help.defs[2].wins)

    local dup = assert(find(res, "n", "<Space>x"))
    ok(dup.duplicate)
    eq("template:" .. ids["<leader>xone"], dup.defs[1].source)
    eq("template:" .. ids["<leader>xtwo"], dup.defs[2].source)
    eq(dup.defs[2].source, dup.defs[1].shadowed_by)

    local gone = assert(find(res, "n", "<Space>v"))
    eq({}, gone.defs)
    eq("default:nvchad", gone.removed[1].source)
    eq("template:raw", gone.removed[1].by)

    eq(nil, find(res, "n", "<Space>w"), "an untouched default is not a conflict")
    eq(nil, find(res, "x", "<Space>q"))
  end)

  it("fails with a reason when the config never finishes", function()
    local root = fake_config()
    write(root .. "/init.lua", { 'vim.g.mapleader = " "', "vim.wait(60000)" })
    assert(template.import { root = root })
    local res, err = template.analyze { root = root, timeout = 2 }
    eq(nil, res)
    ok(err:find("timed out", 1, true), err)
  end)
end)
