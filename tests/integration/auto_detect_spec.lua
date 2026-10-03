-- End to end: real files on the runtimepath, real maps, real model.gather.
-- Run by `make integration` inside a throwaway XDG tree: it writes under
-- stdpath("config") and stdpath("data").
local real = vim.fn.expand "~/.local/share/nvim"
local data_dir = vim.fn.stdpath "data"
if data_dir == real or vim.startswith(data_dir, real .. "/") then
  error("refusing to run: stdpath('data') is the real " .. real .. " (use `make integration`)")
end

local config = require "keymap-helper.config"
local model = require "keymap-helper.model"
local collect = require "keymap-helper.collect"
local track = require "keymap-helper.track"

vim.g.mapleader = " "

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

local cfg_dir = vim.fn.stdpath "config"
local lazy = data_dir .. "/lazy"
vim.fn.mkdir(lazy, "p")

local function build(opts)
  local cfg = config.resolve(opts or { modes = { "n", "i", "x" } })
  return model.build(cfg, model.gather(cfg), collect.normalize, collect.display)
end

local function section(state, title)
  for _, s in ipairs(state.sections) do
    if s.title == title then
      return s
    end
  end
end

local function group(sec, title)
  for _, g in ipairs(sec and sec.groups or {}) do
    if g.title == title then
      return g
    end
  end
end

local function all_lhs(state)
  local out = {}
  for _, s in ipairs(state.sections) do
    for _, g in ipairs(s.groups) do
      for _, r in ipairs(g.rows) do
        out[r.lhs] = (out[r.lhs] or 0) + 1
      end
    end
  end
  return out
end

describe("auto-detected sections (integration)", function()
  write(cfg_dir .. "/lua/kh_it/maps.lua", {
    "local map = vim.keymap.set",
    "-- │ Files │",
    [[map("n", "<leader>if", "<cmd>echo 1<cr>", { desc = "it find" })]],
    [[map({ "n", "x" }, "<leader>ig", function() end, { desc = "it grep" })]],
    [[map("i", "jj", "<Esc>")]],
    [[map("n", "<leader>id", "<cmd>echo 2<cr>", { desc = "it deleted" })]],
    [[vim.keymap.del("n", "<leader>id")]],
  })
  write(lazy .. "/fakeplug.nvim/lua/fakeplug/init.lua", {
    "local map = vim.keymap.set",
    [[map("n", "<leader>pf", function() end, { desc = "fake fn" })]],
    [[map("n", "<leader>ps", "<cmd>echo 3<cr>", { desc = "fake str" })]],
  })
  write(lazy .. "/fakeplug2.nvim/lua/fakeplug2/init.lua", {
    [[vim.keymap.set("n", "<leader>pt", "<cmd>echo 4<cr>", { desc = "fake tracked" })]],
  })
  vim.opt.runtimepath:prepend(cfg_dir)
  vim.opt.runtimepath:prepend(lazy .. "/fakeplug.nvim")
  vim.opt.runtimepath:prepend(lazy .. "/fakeplug2.nvim")
  require "kh_it.maps"
  require "fakeplug"

  it("Your config groups by header, hides deleted and undocumented maps", function()
    local state = build()
    local files = group(section(state, "Your config"), "Files")
    ok(files, "no Files group in Your config: " .. vim.inspect(state.sections[1]))
    eq({
      { modes = "n", lhs = "<leader>if", desc = "it find" },
      { modes = "n,x", lhs = "<leader>ig", desc = "it grep" },
    }, files.rows)
    local seen = all_lhs(state)
    eq(nil, seen["<leader>id"])
    eq(nil, seen["jj"])
  end)

  it("Plugins groups function-rhs maps by plugin; string-rhs ones are shown once somewhere", function()
    local state = build()
    local fp = group(section(state, "Plugins"), "fakeplug.nvim")
    ok(fp, "no fakeplug.nvim group")
    local has_pf = false
    for _, r in ipairs(fp.rows) do
      has_pf = has_pf or (r.lhs == "<leader>pf" and r.desc == "fake fn")
    end
    ok(has_pf, "<leader>pf missing from fakeplug.nvim: " .. vim.inspect(fp.rows))
    -- Where <leader>ps lands depends on what nvim records for a required
    -- module (sid/lnum: Plugins via "sid", or Other when it records none).
    -- Either is fine; losing it or duplicating it is not.
    eq(1, all_lhs(state)["<leader>ps"])
    local in_plugins_or_other = 0
    for _, title in ipairs { "Plugins", "Other" } do
      for _, g in ipairs(section(state, title) and section(state, title).groups or {}) do
        for _, r in ipairs(g.rows) do
          if r.lhs == "<leader>ps" then
            in_plugins_or_other = in_plugins_or_other + 1
          end
        end
      end
    end
    eq(1, in_plugins_or_other)
  end)

  it("Neovim defaults is populated when nvim has default maps", function()
    if vim.fn.maparg("Y", "n") == "" then
      return
    end
    ok(section(build(), "Neovim defaults").count > 0)
  end)

  it("track() attributes a string-rhs plugin map", function()
    ok(track.install())
    require "fakeplug2"
    local state = build()
    track.uninstall()
    track.reset()
    local g = group(section(state, "Plugins"), "fakeplug2.nvim")
    ok(g, "no fakeplug2.nvim group")
    eq({ { modes = "n", lhs = "<leader>pt", desc = "fake tracked" } }, g.rows)
  end)

  it("NvChad-style recipe: overrides show once, deleted defaults vanish", function()
    write(lazy .. "/FakeChad/lua/fakechad/mappings.lua", {
      "local map = vim.keymap.set",
      [[map("n", "<leader>cx", "<cmd>echo 1<cr>", { desc = "chad x" })]],
      [[map("n", "<leader>cd", "<cmd>echo 2<cr>", { desc = "chad del" })]],
      [[map("n", "<leader>co", "<cmd>echo 3<cr>", { desc = "chad over" })]],
    })
    write(cfg_dir .. "/lua/kh_it/chad_user.lua", {
      [[require "fakechad.mappings"]],
      [[vim.keymap.del("n", "<leader>cd")]],
      "local map = vim.keymap.set",
      "-- │ Mine │",
      [[map("n", "<leader>co", "<cmd>echo 2<cr>", { desc = "mine over" })]],
      [[map("i", "kk", "<Esc>")]],
    })
    vim.opt.runtimepath:prepend(lazy .. "/FakeChad")
    require "kh_it.chad_user"
    local state = build {
      modes = { "n", "i", "x" },
      sections = {
        { title = "Custom", files = { "lua/kh_it/chad_user.lua" }, group_by = "header" },
        { title = "NvChad defaults", runtime_files = { "lua/fakechad/mappings.lua" }, collapsed = true },
        { title = "Default", rest = true, collapsed = true },
      },
    }
    local mine = group(section(state, "Custom"), "Mine")
    ok(mine, "no Mine group")
    eq({
      { modes = "n", lhs = "<leader>co", desc = "mine over" },
      { modes = "i", lhs = "kk", desc = "" },
    }, mine.rows)
    eq(
      { { rows = { { modes = "n", lhs = "<leader>cx", desc = "chad x" } } } },
      section(state, "NvChad defaults").groups
    )
    local seen = all_lhs(state)
    eq(nil, seen["<leader>cd"])
    eq(1, seen["<leader>co"])
  end)
end)
