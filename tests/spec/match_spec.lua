local match = require "keymap-helper.match"

local function m(extra)
  return vim.tbl_extend("force", { mode = "n", lhs = "<leader>gb", key = "<Space>gb", desc = "blame" }, extra or {})
end
local function o(extra)
  return vim.tbl_extend("force", { kind = "config", via = "callback" }, extra or {})
end

describe("match.section", function()
  it("no matcher and no rest matches nothing", function()
    eq(false, match.section({ title = "x" }, m(), o(), false))
  end)

  it("rest = true matches anything", function()
    eq(true, match.section({ rest = true }, m(), o { kind = "unknown" }, false))
  end)

  it("rest with an extra matcher is still ANDed", function()
    eq(false, match.section({ rest = true, mode = "n" }, m { mode = "x" }, o(), false))
    eq(true, match.section({ rest = true, mode = "n" }, m(), o(), false))
  end)

  it("config / builtin", function()
    eq(true, match.section({ config = true }, m(), o(), false))
    eq(false, match.section({ config = true }, m(), o { kind = "plugin" }, false))
    eq(true, match.section({ builtin = true }, m(), o { kind = "builtin" }, false))
    eq(false, match.section({ builtin = true }, m(), o(), false))
  end)

  it("plugin = true matches any plugin", function()
    eq(true, match.section({ plugin = true }, m(), o { kind = "plugin", plugin = "x" }, false))
    eq(false, match.section({ plugin = true }, m(), o(), false))
  end)

  it("plugin string is case-insensitive", function()
    local origin = o { kind = "plugin", plugin = "NvChad" }
    eq(true, match.section({ plugin = "nvchad" }, m(), origin, false))
    eq(false, match.section({ plugin = "other" }, m(), origin, false))
  end)

  it("plugin list", function()
    local origin = o { kind = "plugin", plugin = "NvChad" }
    eq(true, match.section({ plugin = { "a", "NvChad" } }, m(), origin, false))
    eq(false, match.section({ plugin = { "a", "b" } }, m(), origin, false))
  end)

  it("files / runtime_files need file_hit", function()
    eq(true, match.section({ files = { "x" } }, m(), o(), true))
    eq(false, match.section({ files = {} }, m(), o(), false))
    eq(true, match.section({ runtime_files = { "x" } }, m(), o(), true))
    eq(false, match.section({ files = { "x" }, runtime_files = { "y" } }, m(), o(), false))
  end)

  it("lhs and desc are Lua patterns", function()
    eq(true, match.section({ lhs = "^<leader>g" }, m(), o(), false))
    eq(false, match.section({ lhs = "^<leader>h" }, m(), o(), false))
    eq(true, match.section({ desc = "blam" }, m(), o(), false))
    eq(false, match.section({ desc = "blam" }, m { desc = "" }, o(), false))
  end)

  it("desc pattern against an empty desc", function()
    eq(false, match.section({ desc = ".+" }, m { desc = "" }, o(), false))
    eq(true, match.section({ desc = "^$" }, m { desc = "" }, o(), false))
  end)

  it("mode string and list", function()
    eq(true, match.section({ mode = "n" }, m(), o(), false))
    eq(false, match.section({ mode = "x" }, m(), o(), false))
    eq(true, match.section({ mode = { "x", "n" } }, m(), o(), false))
  end)

  it("fn gets (m, origin) and its truthiness decides", function()
    local seen
    local f = function(mm, oo)
      seen = { mm, oo }
      return oo.kind == "config"
    end
    eq(true, match.section({ fn = f }, m(), o(), false))
    eq("<leader>gb", seen[1].lhs)
    eq("config", seen[2].kind)
    eq(false, match.section({ fn = f }, m(), o { kind = "plugin" }, false))
  end)

  it("an erroring fn counts as false and does not throw", function()
    local res
    local okk = pcall(function()
      res = match.section({
        fn = function()
          error "boom"
        end,
      }, m(), o(), false)
    end)
    eq(true, okk)
    eq(false, res)
  end)

  it("keys are ANDed", function()
    eq(true, match.section({ config = true, lhs = "^<leader>g" }, m(), o(), false))
    eq(false, match.section({ config = true, lhs = "^<leader>h" }, m(), o(), false))
    eq(false, match.section({ config = true, lhs = "^<leader>g" }, m(), o { kind = "plugin" }, false))
  end)
end)

describe("match.has_files", function()
  it("is true for files or runtime_files", function()
    eq(true, match.has_files { files = {} })
    eq(true, match.has_files { runtime_files = {} })
    eq(false, match.has_files { config = true })
  end)
end)

describe("match bad patterns", function()
  it("treats an invalid lhs/desc pattern as no match instead of throwing", function()
    local m = { mode = "n", lhs = "<leader>x", desc = "d" }
    local o = { kind = "config", via = "index" }
    eq(false, require("keymap-helper.match").section({ title = "t", lhs = "[" }, m, o, false))
    eq(false, require("keymap-helper.match").section({ title = "t", desc = "%" }, m, o, false))
  end)
end)
