local config = require "keymap-helper.config"

local function quiet(fn)
  local notify = vim.notify
  vim.notify = function() end
  local a, b = fn()
  vim.notify = notify
  return a, b
end

describe("config", function()
  it("resolves defaults with no opts", function()
    local cfg, unknown = config.resolve()
    eq(config.defaults, cfg)
    eq({}, unknown)
  end)

  it("reports unknown keys instead of ignoring them", function()
    local _, unknown = quiet(function()
      return config.resolve { hnt = {}, hint = { nope = 1 } }
    end)
    table.sort(unknown)
    eq({ "hint.nope", "hnt" }, unknown)
  end)

  it("does not mutate the defaults table", function()
    local before = vim.deepcopy(config.defaults)
    config.resolve { hint = { enabled = false }, sections = { { title = "x", rest = true } } }
    eq(before, config.defaults)
  end)

  it("replaces list options wholesale instead of merging by index", function()
    local cfg = config.resolve { sections = { { title = "Only", rest = true } }, modes = { "n" } }
    eq({ { title = "Only", rest = true } }, cfg.sections)
    eq({ "n" }, cfg.modes)
  end)

  it("rejects a section without a title, naming the option", function()
    local okk, err = pcall(config.resolve, { sections = { { files = {} } } })
    eq(false, okk)
    ok(tostring(err):find "sections%[1%]%.title", err)
  end)

  it("defaults hint.position to center", function()
    eq("center", config.defaults.hint.position)
    local cfg = config.resolve()
    eq("center", cfg.hint.position)
  end)

  it("accepts hint.position = bottom_right", function()
    local cfg = quiet(function()
      return config.resolve { hint = { position = "bottom_right" } }
    end)
    eq("bottom_right", cfg.hint.position)
  end)

  it("rejects a bad hint.position, naming the option", function()
    local okk, err = pcall(function()
      return quiet(function()
        return config.resolve { hint = { position = "middle" } }
      end)
    end)
    eq(false, okk)
    ok(tostring(err):find("hint.position", 1, true), err)
  end)
end)
