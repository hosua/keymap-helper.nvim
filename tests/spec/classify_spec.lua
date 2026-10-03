local classify = require "keymap-helper.classify"

local env = {
  config_dirs = { "/cfg" },
  lazy_root = "/data/lazy",
  vimruntime = "/rt",
  rtp = { "/cfg", "/data/lazy/foo.nvim", "/dev/bar.nvim", "/dev/bar.nvim/after", "/rt" },
}

describe("classify.path", function()
  local function check(path, kind, plugin)
    local p = classify.path(path, env)
    eq(kind, p.kind, path)
    eq(plugin, p.plugin, path)
    eq(path, p.file, path)
  end

  it("config dir files are config", function()
    check("/cfg/lua/m.lua", "config")
  end)

  it("respects the directory boundary", function()
    check("/cfgx/a.lua", "unknown")
  end)

  it("lazy root: plugin is the first component", function()
    check("/data/lazy/NvChad/lua/nvchad/mappings.lua", "plugin", "NvChad")
  end)

  it("rtp entries name dev plugins", function()
    check("/dev/bar.nvim/lua/bar.lua", "plugin", "bar.nvim")
  end)

  it("rtp after/ dirs use the parent name", function()
    check("/dev/bar.nvim/after/plugin/x.lua", "plugin", "bar.nvim")
  end)

  it("vimruntime is builtin", function()
    check("/rt/lua/vim/x.lua", "builtin")
  end)

  it("packs inside vimruntime stay builtin", function()
    check("/rt/pack/dist/opt/matchit/plugin/matchit.vim", "builtin")
  end)

  it("pack/*/opt/<name> is a plugin", function()
    check("/x/site/pack/core/opt/fzf/lua/f.lua", "plugin", "fzf")
  end)

  it("pack/*/start/<name> beats the config dir", function()
    check("/cfg/pack/p/start/myplug/plugin/x.lua", "plugin", "myplug")
  end)

  it("anything else is unknown, keeping the file", function()
    eq({ kind = "unknown", file = "/elsewhere/x.lua" }, classify.path("/elsewhere/x.lua", env))
  end)
end)

describe("classify.source", function()
  it("@vim/ sources are builtin without a file", function()
    eq({ kind = "builtin" }, classify.source("@vim/_core/defaults", env))
  end)

  it("@path sources classify the path", function()
    eq("config", classify.source("@/cfg/init.lua", env).kind)
    eq("/cfg/init.lua", classify.source("@/cfg/init.lua", env).file)
  end)

  it("non-file sources are nil", function()
    eq(nil, classify.source("=[string]", env))
    eq(nil, classify.source(nil, env))
  end)
end)

describe("classify.is_builtin_desc", function()
  it("matches nvim's default-map descriptions", function()
    eq(true, classify.is_builtin_desc ":help Y-default")
    eq(true, classify.is_builtin_desc ":help v_#-default")
  end)

  it("rejects everything else", function()
    eq(false, classify.is_builtin_desc "help")
    eq(false, classify.is_builtin_desc(nil))
  end)
end)

describe("classify.env", function()
  it("returns the expected shape", function()
    local e = classify.env()
    eq("table", type(e.config_dirs))
    ok(#e.config_dirs >= 1)
    eq("string", type(e.vimruntime))
    eq("table", type(e.rtp))
    for _, d in ipairs(e.config_dirs) do
      ok(d:sub(-1) ~= "/", "trailing slash: " .. d)
    end
  end)
end)
