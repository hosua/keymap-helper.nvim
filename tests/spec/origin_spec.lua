local origin = require "keymap-helper.origin"

local env = {
  config_dirs = { "/cfg" },
  lazy_root = "/data/lazy",
  vimruntime = "/rt",
  rtp = { "/cfg", "/data/lazy/foo.nvim", "/dev/bar.nvim", "/dev/bar.nvim/after", "/rt" },
}

local function ident(s)
  return s
end

local function cb(path)
  return load("return function() end", "@" .. path)()
end

local cfg_cb = cb "/cfg/lua/mappings.lua"
local gitsigns_cb = cb "/data/lazy/gitsigns.nvim/lua/gitsigns.lua"
local stub_cb = cb "/data/lazy/lazy.nvim/lua/lazy/core/handler/keys.lua"
local defaults_cb = load("return function() end", "@vim/_core/defaults")()
local other_cb = cb "/cfg/lua/other.lua"

local function ctx(extra)
  return vim.tbl_extend("force", {
    tracked = {},
    lazy_keys = {},
    index = {},
    getinfo = origin.getinfo,
    scriptinfo = function(sid)
      if sid == 5 then
        return "/cfg/init.lua"
      end
      error("scriptinfo called for sid " .. tostring(sid))
    end,
    env = env,
  }, extra or {})
end

local function map(extra)
  return vim.tbl_extend("force", { mode = "n", lhs = "<leader>a", desc = "x" }, extra or {})
end

describe("origin.resolve", function()
  it("1 track wins over callback", function()
    local c = ctx { tracked = { ["n<leader>a"] = { source = "/cfg/lua/a.lua", line = 3 } } }
    eq({ kind = "config", file = "/cfg/lua/a.lua", via = "track" }, origin.resolve(map { callback = gitsigns_cb }, c))
  end)

  it("2 lazy_keys wins over the lazy stub callback", function()
    local c = ctx { lazy_keys = { ["n<leader>ff"] = "telescope.nvim" } }
    eq(
      { kind = "plugin", plugin = "telescope.nvim", via = "lazy_keys" },
      origin.resolve(map { lhs = "<leader>ff", callback = stub_cb }, c)
    )
  end)

  it("3 config callback", function()
    eq(
      { kind = "config", file = "/cfg/lua/mappings.lua", via = "callback" },
      origin.resolve(map { callback = cfg_cb }, ctx())
    )
  end)

  it("4 plugin callback", function()
    eq({
      kind = "plugin",
      plugin = "gitsigns.nvim",
      file = "/data/lazy/gitsigns.nvim/lua/gitsigns.lua",
      via = "callback",
    }, origin.resolve(map { callback = gitsigns_cb }, ctx()))
  end)

  it("5 lazy stub callback alone is unknown", function()
    eq({ kind = "unknown", via = "none" }, origin.resolve(map { callback = stub_cb }, ctx()))
  end)

  it("6 nvim defaults callback is builtin", function()
    eq({ kind = "builtin", via = "callback" }, origin.resolve(map { callback = defaults_cb }, ctx()))
  end)

  it("7 sid with a line resolves the script", function()
    eq({ kind = "config", file = "/cfg/init.lua", via = "sid" }, origin.resolve(map { sid = 5, lnum = 10 }, ctx()))
  end)

  it("8 sid with lnum 0 is ignored (module required by a script)", function()
    eq({ kind = "unknown", via = "none" }, origin.resolve(map { sid = 5, lnum = 0 }, ctx()))
  end)

  it("9 negative sid is ignored", function()
    eq({ kind = "unknown", via = "none" }, origin.resolve(map { sid = -8, lnum = 0 }, ctx()))
  end)

  local hit = { file = "/cfg/lua/mappings.lua", group = "Lines", order = 4 }

  it("10 index alone gives config with group and order", function()
    eq(
      { kind = "config", file = "/cfg/lua/mappings.lua", group = "Lines", order = 4, via = "index" },
      origin.resolve(map { lhs = "<leader>ln" }, ctx { index = { ["n<leader>ln"] = hit } })
    )
  end)

  it("11 callback in the same file also gets group and order", function()
    eq(
      { kind = "config", file = "/cfg/lua/mappings.lua", group = "Lines", order = 4, via = "callback" },
      origin.resolve(map { lhs = "<leader>ln", callback = cfg_cb }, ctx { index = { ["n<leader>ln"] = hit } })
    )
  end)

  it("12 callback in another file gets no group or order", function()
    eq(
      { kind = "config", file = "/cfg/lua/other.lua", via = "callback" },
      origin.resolve(map { lhs = "<leader>ln", callback = other_cb }, ctx { index = { ["n<leader>ln"] = hit } })
    )
  end)

  it("13 builtin desc heuristic", function()
    eq({ kind = "builtin", via = "heuristic" }, origin.resolve(map { desc = ":help Y-default" }, ctx()))
  end)

  it("returns a new table each call", function()
    local c = ctx()
    local a = origin.resolve(map { callback = cfg_cb }, c)
    a.kind = "mutated"
    eq("config", origin.resolve(map { callback = cfg_cb }, c).kind)
  end)
end)

describe("origin.lazy_keys_from", function()
  it("maps keys specs to plugin names, skipping ft keys", function()
    local plugins = {
      t = {
        name = "telescope.nvim",
        _ = {
          handlers = {
            keys = {
              a = { lhs = "<leader>ff", mode = "n" },
              b = { lhs = "<leader>fg", mode = "x" },
              c = { lhs = "q", mode = "n", ft = "help" },
            },
          },
        },
      },
      x = { name = "x", _ = {} },
    }
    eq(
      { ["n<leader>ff"] = "telescope.nvim", ["x<leader>fg"] = "telescope.nvim" },
      origin.lazy_keys_from(plugins, ident)
    )
  end)
end)

describe("origin.getinfo / scriptinfo", function()
  it("getinfo returns a function's source", function()
    eq("@/cfg/lua/mappings.lua", origin.getinfo(cfg_cb))
  end)

  it("scriptinfo does not throw for a bogus sid", function()
    local okk = pcall(origin.scriptinfo, 99999)
    eq(true, okk)
  end)
end)
