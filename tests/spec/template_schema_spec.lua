local schema = require "keymap-helper.template.schema"
local json = require "keymap-helper.template.json"

local function valid()
  local t = schema.new()
  t.entries = {
    { id = "a", kind = "map", category = "uncategorized", modes = { "n" }, lhs = "x", rhs = "y" },
    { id = "b", kind = "raw", category = "uncategorized", text = "local z = 1" },
  }
  return t
end

local function errors(mutate)
  local t = valid()
  mutate(t)
  return table.concat(schema.validate(t), "\n")
end

describe("template schema", function()
  it("accepts a valid template and a fresh one", function()
    eq({}, schema.validate(valid()))
    eq({}, schema.validate(schema.new()))
  end)

  it("rejects a version it cannot read", function()
    ok(errors(function(t)
      t.version = 2
    end):find("version must be 1", 1, true))
  end)

  it("requires the uncategorized category", function()
    ok(errors(function(t)
      t.categories = { { id = "general", title = "General" } }
      t.entries = {}
    end):find('must include id "uncategorized"', 1, true))
  end)

  it("catches a duplicate entry id, an unknown category and an unknown key", function()
    local e = errors(function(t)
      t.entries[2].id = "a"
      t.entries[1].category = "nope"
      t.entries[1].typo = true
    end)
    ok(e:find('id "a" is used twice', 1, true), e)
    ok(e:find('category "nope" is not in categories', 1, true), e)
    ok(e:find('unknown key "typo"', 1, true), e)
  end)

  it("allows keys that start with an underscore for other tools", function()
    eq(
      {},
      schema.validate((function()
        local t = valid()
        t.entries[1]._tags = { "x" }
        return t
      end)())
    )
  end)

  it("needs exactly one of rhs and lua", function()
    ok(errors(function(t)
      t.entries[1].lua = "function() end"
    end):find("exactly one of", 1, true))
    ok(errors(function(t)
      t.entries[1].rhs = nil
    end):find("exactly one of", 1, true))
  end)

  it("checks modes, lhs and option types", function()
    local e = errors(function(t)
      t.entries[1].modes = {}
      t.entries[1].lhs = ""
      t.entries[1].opts = { desc = 1, bogus = true }
      t.entries[1].opts_raw = { desc = "x" }
    end)
    ok(e:find("modes must be a non-empty list", 1, true), e)
    ok(e:find("lhs must be a non-empty string", 1, true), e)
    ok(e:find("opts.desc must be string", 1, true), e)
    ok(e:find("opts.bogus is not a typed option", 1, true), e)
  end)

  it("rejects an option listed in both opts and opts_raw", function()
    ok(errors(function(t)
      t.entries[1].opts = { desc = "a" }
      t.entries[1].opts_raw = { desc = "b" }
    end):find("is in both opts and opts_raw", 1, true))
  end)

  it("needs text on a raw entry and a known kind", function()
    ok(errors(function(t)
      t.entries[2].text = nil
    end):find("raw entry needs `text`", 1, true))
    ok(errors(function(t)
      t.entries[2].kind = "weird"
    end):find("kind must be", 1, true))
  end)

  it("does not throw on garbage", function()
    eq({ "template must be a JSON object" }, schema.validate "x")
    ok(#schema.validate { version = 1, target = 1, preamble = 3, categories = 4, entries = 5 } >= 4)
  end)

  it("joins lists of lines in text fields", function()
    local t = valid()
    t.preamble = { { "a", "b" } }
    t.entries[1].lua = { "function()", "end" }
    local n = schema.normalize(t)
    eq("a\nb", n.preamble[1])
    eq("function()\nend", n.entries[1].lua)
    eq({ "a", "b" }, t.preamble[1], "input is not modified")
  end)

  it("slugs titles", function()
    eq("retired-nvchad-defaults", schema.slug "Retired NvChad Defaults")
    eq("category", schema.slug "!!!")
  end)
end)

describe("template json", function()
  it("round-trips a template, writing multi-line text as lines", function()
    local t = valid()
    t.entries[1].rhs = nil
    t.entries[1].lua = "function()\n  x()\nend"
    t.preamble = { "a\nb" }
    local text = json.encode(t)
    ok(text:find('"function()",', 1, true), text)
    local back = schema.normalize(assert(json.decode(text)))
    eq(t, back)
  end)

  it("does not escape slashes and writes empty lists as []", function()
    local t = schema.new()
    t.entries =
      { { id = "a", kind = "map", category = "uncategorized", modes = { "n" }, lhs = "<leader>/", rhs = "x" } }
    local text = json.encode(t)
    ok(text:find("<leader>/", 1, true))
    ok(not text:find("\\/", 1, true))
    ok(json.encode(schema.new()):find('"entries": []', 1, true))
    ok(json.encode(schema.new()):find('"preamble": []', 1, true))
  end)

  it("is deterministic", function()
    local t = valid()
    eq(json.encode(t), json.encode(vim.deepcopy(t)))
  end)

  it("reports invalid JSON", function()
    local v, err = json.decode "{ nope"
    eq(nil, v)
    ok(err and err ~= "")
  end)
end)
