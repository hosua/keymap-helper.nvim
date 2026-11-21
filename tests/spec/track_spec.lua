local track = require "keymap-helper.track"

vim.g.mapleader = " "

local function cleanup(...)
  track.uninstall()
  track.reset()
  for _, spec in ipairs { ... } do
    pcall(vim.keymap.del, spec[1], spec[2])
  end
end

describe("track.expand_modes", function()
  it("expands like nvim_set_keymap's shortnames", function()
    eq({ "n" }, track.expand_modes "n")
    eq({ "n", "x" }, track.expand_modes { "n", "x" })
    eq({ "n", "v", "x", "s", "o" }, track.expand_modes "")
    eq({ "v", "x", "s" }, track.expand_modes "v")
    eq({ "!", "i", "c" }, track.expand_modes "!")
    eq({ "n", "v", "x", "s" }, track.expand_modes { "n", "v", "x" })
  end)
end)

describe("track.pick_caller", function()
  local frames = {
    { source = "@vim/keymap.lua", currentline = 1 },
    { source = "=[string]" },
    { source = "@/d/lazy.nvim/lua/lazy/core/loader.lua", currentline = 2 },
    { source = "@/cfg/lua/p.lua", currentline = 9 },
  }

  it("returns the first non-skipped file frame", function()
    eq({ source = "/cfg/lua/p.lua", line = 9 }, track.pick_caller(frames, track.SKIP))
  end)

  it("returns nil when every frame is skipped", function()
    eq(nil, track.pick_caller(vim.list_slice(frames, 1, 3), track.SKIP))
  end)
end)

describe("track.install", function()
  local saved = vim.keymap.set

  it("installs once and is idempotent", function()
    eq(true, track.install())
    local wrapper = vim.keymap.set
    ok(wrapper ~= saved)
    eq(true, track.installed())
    eq(true, track.install())
    ok(rawequal(wrapper, vim.keymap.set), "second install re-wrapped")
    cleanup()
  end)

  it("records the global caller's file and line", function()
    track.reset()
    track.install()
    local line = debug.getinfo(1, "l").currentline + 1
    vim.keymap.set("n", "<leader>tq", "<cmd>echo 1<cr>", { desc = "t" })
    local rec = track.registry()["n<Space>tq"]
    ok(rec, "not recorded: " .. vim.inspect(track.registry()))
    ok(rec.source:find("tests/spec/track_spec.lua$", 1), rec.source)
    eq(line, rec.line)
    cleanup { "n", "<leader>tq" }
  end)

  it("records every mode of a list", function()
    track.reset()
    track.install()
    vim.keymap.set({ "n", "x" }, "<leader>tm", "<cmd>echo 1<cr>")
    local r = track.registry()
    ok(r["n<Space>tm"] and r["x<Space>tm"], vim.inspect(r))
    cleanup({ "n", "<leader>tm" }, { "x", "<leader>tm" })
  end)

  it("ignores buffer-local maps", function()
    track.reset()
    track.install()
    vim.keymap.set("n", "<leader>tb", "<cmd>echo 1<cr>", { buffer = 0 })
    eq(nil, track.registry()["n<Space>tb"])
    cleanup()
    pcall(vim.keymap.del, "n", "<leader>tb", { buffer = 0 })
  end)

  it("records nothing and propagates errors from a bad call", function()
    track.reset()
    track.install()
    local okk = pcall(vim.keymap.set, "Z", "a", "b")
    eq(false, okk)
    eq({}, track.registry())
    cleanup()
  end)

  it("registry() returns a copy", function()
    track.reset()
    track.install()
    vim.keymap.set("n", "<leader>tc", "<cmd>echo 1<cr>")
    local copy = track.registry()
    copy["n<Space>tc"] = nil
    copy.bogus = { source = "x", line = 1 }
    local again = track.registry()
    ok(again["n<Space>tc"], "mutation leaked into the registry")
    eq(nil, again.bogus)
    cleanup { "n", "<leader>tc" }
  end)

  it("uninstall restores the original once", function()
    track.install()
    eq(true, track.uninstall())
    ok(rawequal(vim.keymap.set, saved), "original not restored")
    eq(false, track.uninstall())
    track.reset()
  end)

  it("refuses when someone wrapped over us", function()
    track.install()
    local wrapper = vim.keymap.set
    local other = function(...)
      return wrapper(...)
    end
    vim.keymap.set = other
    eq(false, track.install())
    eq(false, track.uninstall())
    ok(vim.keymap.set == other)
    vim.keymap.set = wrapper
    cleanup()
    ok(rawequal(vim.keymap.set, saved), "teardown failed to restore")
  end)
end)

describe("track review fixes", function()
  local track = require "keymap-helper.track"

  it("records nothing for a lazy.nvim keys stub, even with a user frame above it", function()
    eq(
      nil,
      track.pick_caller({
        { source = "@/x/lazy.nvim/lua/lazy/core/handler/keys.lua", currentline = 10 },
        { source = "@/cfg/init.lua", currentline = 3 },
      }, track.SKIP)
    )
  end)

  it("a wrapper captured before uninstall() still sets maps and stops recording", function()
    track.uninstall()
    track.reset()
    ok(track.install())
    local captured = vim.keymap.set
    track.uninstall()
    track.reset()
    captured("n", "<F13>", "<cmd>echo 1<cr>", { desc = "stale wrapper" })
    local found = vim.fn.maparg("<F13>", "n", false, true)
    eq("stale wrapper", found.desc)
    eq({}, track.registry())
    vim.keymap.del("n", "<F13>")
  end)
end)
