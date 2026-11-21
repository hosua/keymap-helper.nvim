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

  it("rejects a non-boolean section collapsed, naming the option", function()
    local okk, err =
      pcall(config.resolve, { sections = { { title = "x", rest = true }, { title = "y", collapsed = "yes" } } })
    eq(false, okk)
    ok(tostring(err):find "sections%[2%]%.collapsed", err)
  end)

  it("accepts boolean collapsed", function()
    local cfg = config.resolve { sections = { { title = "x", rest = true, collapsed = true } } }
    eq(true, cfg.sections[1].collapsed)
  end)

  it("has no footer option: the footer is generated from the bound keys", function()
    eq(nil, config.defaults.window.footer)
    local _, unknown = quiet(function()
      return config.resolve { window = { footer = "x" } }
    end)
    eq({ "window.footer" }, unknown)
  end)
end)

describe("config auto-detect", function()
  it("has the documented default sections", function()
    eq({
      { title = "Default", subtitle = "everything else with a description", rest = true, collapsed = false },
    }, config.defaults.sections)
  end)

  it("has the documented detect defaults", function()
    eq(false, config.defaults.show_undocumented)
    eq({ scan_config = true, max_files = 200, lazy_keys = true, which_key = true }, config.defaults.detect)
  end)

  it("merges detect per key", function()
    local cfg = config.resolve { detect = { max_files = 10 } }
    eq({ scan_config = true, max_files = 10, lazy_keys = true, which_key = true }, cfg.detect)
  end)

  it("reports a misspelled section key as unknown", function()
    local _, unknown = quiet(function()
      return config.resolve { sections = { { title = "x", colapsed = true, rest = true } } }
    end)
    eq({ "sections[1].colapsed" }, unknown)
  end)

  local function rejects(section, key)
    local okk, err = pcall(function()
      return quiet(function()
        return config.resolve { sections = { vim.tbl_extend("force", { title = "x", rest = true }, section) } }
      end)
    end)
    eq(false, okk, key)
    ok(tostring(err):find("sections[1]." .. key, 1, true), tostring(err))
  end

  it("validates the new section keys, naming the option", function()
    rejects({ group_by = "bogus" }, "group_by")
    rejects({ plugin = 5 }, "plugin")
    rejects({ fn = "x" }, "fn")
    rejects({ hidden = "y" }, "hidden")
  end)

  it("accepts every group_by and matcher key", function()
    for _, g in ipairs { "header", "plugin", "leader_prefix", "none" } do
      local cfg = config.resolve { sections = { { title = "x", config = true, group_by = g } } }
      eq(g, cfg.sections[1].group_by)
    end
    local cfg, unknown = config.resolve {
      sections = {
        {
          title = "x",
          builtin = true,
          plugin = { "a" },
          lhs = "^a",
          desc = "d",
          mode = { "n" },
          fn = function() end,
          hidden = true,
          subtitle = "s",
        },
      },
    }
    eq({}, unknown)
    eq(true, cfg.sections[1].hidden)
  end)

  it("rejects bad show_undocumented and detect.max_files", function()
    ok(not pcall(config.resolve, { show_undocumented = "yes" }))
    ok(not pcall(config.resolve, { detect = { max_files = 0 } }))
    ok(not pcall(config.resolve, { detect = { max_files = 1.5 } }))
  end)

  it("accepts the NvChad recipe with no unknown keys", function()
    local _, unknown = config.resolve {
      sections = {
        { title = "Custom", subtitle = "lua/mappings.lua", files = { "lua/mappings.lua" }, group_by = "header" },
        { title = "NvChad defaults", runtime_files = { "lua/nvchad/mappings.lua" }, collapsed = true },
      },
    }
    eq({}, unknown)
  end)
end)

describe("config keymap", function()
  it("defaults to <leader>km", function()
    eq("<leader>km", config.defaults.keymap)
    eq("<leader>km", config.resolve().keymap)
  end)

  it("accepts false", function()
    local cfg, unknown = config.resolve { keymap = false }
    eq(false, cfg.keymap)
    eq({}, unknown)
  end)

  it("accepts a key string with no unknown keys", function()
    local cfg, unknown = config.resolve { keymap = "<leader>?" }
    eq("<leader>?", cfg.keymap)
    eq({}, unknown)
  end)

  it("rejects a non-string and an empty string, naming the option", function()
    for _, bad in ipairs { 5, "" } do
      local okk, err = pcall(config.resolve, { keymap = bad })
      eq(false, okk)
      ok(tostring(err):find("keymap", 1, true), tostring(err))
    end
  end)
end)
