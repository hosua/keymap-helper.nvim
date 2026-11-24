local import = require "keymap-helper.template.import"
local generate = require "keymap-helper.template.generate"
local schema = require "keymap-helper.template.schema"

local function parse(src, opts)
  local t = import.parse(src, opts)
  eq({}, schema.validate(t))
  return t
end

local function only(src, opts)
  local t = parse(src, opts)
  eq(1, #t.entries, vim.inspect(t.entries))
  return t.entries[1], t
end

describe("template import: map shapes", function()
  it("reads a string mode, a string rhs and a desc", function()
    local e = only [[map("n", ";", ":", { desc = "CMD" })]]
    eq("map", e.kind)
    eq({ "n" }, e.modes)
    eq(";", e.lhs)
    eq(":", e.rhs)
    eq({ desc = "CMD" }, e.opts)
    eq("uncategorized", e.category)
    eq(nil, e.lua)
  end)

  it("reads a table of modes", function()
    local e = only [[vim.keymap.set({ "n", "x" }, "<leader>q", "<cmd>q<CR>")]]
    eq({ "n", "x" }, e.modes)
    eq("vim.keymap.set", e.call)
    eq(nil, e.opts)
  end)

  it("keeps a closure verbatim in `lua`", function()
    local e = only 'map("n", "a", function()\n  require("x").y()\nend, { desc = "d", silent = true })'
    eq('function()\n  require("x").y()\nend', e.lua)
    eq(nil, e.rhs)
    eq({ desc = "d", silent = true }, e.opts)
  end)

  it("keeps an expression rhs verbatim in `lua`", function()
    local e = only [[map("n", "a", require("x").fn)]]
    eq('require("x").fn', e.lua)
  end)

  it("reads typed option values and leaves other options verbatim", function()
    local e =
      only [[map("n", "a", "b", { desc = "d", expr = true, remap = false, buffer = 0, mystery = 1 + 2, unique = vim.g.u })]]
    eq({ desc = "d", expr = true, remap = false, buffer = 0 }, e.opts)
    eq({ mystery = "1 + 2", unique = "vim.g.u" }, e.opts_raw)
  end)

  it("reads escapes and quotes in strings", function()
    local e = only [==[map("n", '"', "a\"b\\n", { desc = [[long]] })]==]
    eq('"', e.lhs)
    eq('a"b\\n', e.rhs)
    eq("long", e.opts.desc)
  end)

  it("keeps the comment above a map and a trailing comment", function()
    local e = only '-- why\n-- more\nmap("n", "a", "b") -- tail'
    eq("-- why\n-- more", e.comment)
    eq("-- tail", e.trailing)
  end)

  it("does not attach a comment separated by a blank line", function()
    local t = parse '-- free\n\nmap("n", "a", "b")'
    eq({ "-- free" }, t.preamble)
    eq(nil, t.entries[1].comment)
  end)
end)

describe("template import: raw preservation", function()
  local function raw_of(src)
    local t = parse(src)
    local texts = vim.list_extend({}, t.preamble)
    for _, e in ipairs(t.entries) do
      texts[#texts + 1] = e.kind == "raw" and e.text or ("<" .. e.lhs .. ">")
    end
    return texts
  end

  it("keeps requires and locals before the first map as preamble", function()
    local t = parse 'require "x"\nlocal map = vim.keymap.set\nmap("n", "a", "b")'
    eq({ 'require "x"', "local map = vim.keymap.set" }, t.preamble)
    eq(1, #t.entries)
  end)

  it("keeps a loop that creates maps as raw, in place", function()
    local src = 'map("n", "a", "b")\nfor k, v in pairs { a = 1 } do\n  map("n", k, v)\nend\nmap("n", "c", "d")'
    eq({ "<a>", 'for k, v in pairs { a = 1 } do\n  map("n", k, v)\nend', "<c>" }, raw_of(src))
  end)

  it("keeps calls it cannot model as raw", function()
    for _, src in ipairs {
      'map(mode, "a", "b")', -- mode is a variable
      'map("n", prefix .. "a", "b")', -- lhs is an expression
      'map("n", "a", "b", opts)', -- opts is a variable
      'map("n", "a", "b", { desc = "x", desc = "y" })', -- duplicate key
      'map("n", "a", "b", { ["desc"] = "x" })', -- bracket key
      'map("n", "a", "b", { "x" })', -- positional
      'map("n", "a", "b", {}, 1)', -- five arguments
      'map("n", "a")', -- too few
      'pcall(map, "n", "a", "b")',
      'map "n"',
      'map({ m }, "a", "b")',
    } do
      local t = parse('map("n", "z", "z")\n' .. src)
      eq(2, #t.entries, src)
      eq("raw", t.entries[2].kind, src)
      eq(src, t.entries[2].text, src)
    end
  end)

  it("keeps a comment inside a call's arguments by making the call raw", function()
    local t = parse 'map("n", "a", "b", {\n  desc = "x", -- keep\n})'
    eq(1, #t.preamble + #t.entries)
    eq("raw", (t.entries[1] or {}).kind or "raw")
  end)

  it("keeps local functions and free comments between maps in order", function()
    local src = 'map("n", "a", "b")\n\n-- section note\n\nlocal function f() end\n\nmap("n", "c", "d")'
    eq({ "<a>", "-- section note", "local function f() end", "<c>" }, raw_of(src))
  end)

  it("keeps a lead and trailing comment on a raw statement", function()
    local t = parse 'map("n", "z", "z")\n-- lead\nlocal x = 1 -- tail'
    eq("-- lead\nlocal x = 1 -- tail", t.entries[2].text)
  end)

  it("keeps a syntax error as raw instead of dropping it", function()
    local t = parse 'map("n", "a", "b")\nmap("n", "c",\n'
    local all = vim.inspect(t)
    ok(all:find('"c"', 1, true), all)
  end)
end)

describe("template import: headers", function()
  local SRC = table.concat({
    "local map = vim.keymap.set",
    "",
    generate.box "General",
    "",
    'map("n", "a", "b")',
    "",
    generate.box "Splits",
    "",
    'map("n", "c", "d")',
  }, "\n")

  it("keeps headers by default: each one becomes a category", function()
    local t = parse(SRC)
    eq(
      { "uncategorized", "general", "splits" },
      vim.tbl_map(function(c)
        return c.id
      end, t.categories)
    )
  end)

  it("drop_headers makes everything uncategorized", function()
    local t = parse(SRC, { drop_headers = true })
    eq(
      { "uncategorized" },
      vim.tbl_map(function(c)
        return c.id
      end, t.categories)
    )
    for _, e in ipairs(t.entries) do
      eq("uncategorized", e.category)
    end
  end)

  it("keep_headers = false is the same as drop_headers", function()
    local t = parse(SRC, { keep_headers = false })
    eq(1, #t.categories)
  end)

  it("reads the old three-line box headers too", function()
    local box = table.concat({
      "-- ┌───────────────────┐",
      "-- │ General           │",
      "-- └───────────────────┘",
    }, "\n")
    local old = parse(
      "local map = vim.keymap.set\n\n"
        .. box
        .. '\nmap("n","a","b")\n\n'
        .. box:gsub("General", "Splits")
        .. '\nmap("n","c","d")'
    )
    local new = parse(SRC)
    eq(
      vim.tbl_map(function(c)
        return c.title
      end, new.categories),
      vim.tbl_map(function(c)
        return c.title
      end, old.categories)
    )
    eq(
      { "general", "splits" },
      vim.tbl_map(function(e)
        return e.category
      end, old.entries)
    )
    eq({ "local map = vim.keymap.set" }, old.preamble)
  end)

  it("regenerates old box headers as the one-line header, same categories", function()
    local box = "-- ┌─────┐\n-- │ General │\n-- └─────┘"
    local t1 = parse(box .. '\nmap("n","a","b")')
    local out = generate.strip_header(generate.render(t1))
    ok(out:find("-- [General]", 1, true), out)
    ok(not out:find("┌", 1, true), out)
    local t2 = parse(out)
    eq(t1.categories, t2.categories)
    eq(t1.entries, t2.entries)
  end)

  it("import -> generate -> import is stable, with and without a subtitle", function()
    local src = 'local map = vim.keymap.set\n\n-- [A]\nmap("n","a","b")\n\n-- [B]\n-- the b keys\n\nmap("n","c","d")\n'
    local t1 = parse(src)
    local out1 = generate.render(t1)
    local t2 = parse(generate.strip_header(out1))
    eq(t1.categories, t2.categories)
    eq(t1.entries, t2.entries)
    eq(out1, generate.render(t2))
  end)

  it("a bracketed word inside a normal comment is not a header", function()
    local t = parse '-- [x] todo later\nmap("n","a","b")'
    eq(1, #t.categories)
  end)

  it("keep_headers turns them into categories", function()
    local t = parse(SRC, { keep_headers = true })
    eq(
      { "uncategorized", "general", "splits" },
      vim.tbl_map(function(c)
        return c.id
      end, t.categories)
    )
    eq(
      { "general", "splits" },
      vim.tbl_map(function(e)
        return e.category
      end, t.entries)
    )
    eq({ "local map = vim.keymap.set" }, t.preamble)
  end)

  it("reuses a category for a repeated title", function()
    local src = generate.box "A"
      .. '\nmap("n","a","b")\n\n'
      .. generate.box "B"
      .. '\nmap("n","c","d")\n\n'
      .. generate.box "A"
      .. '\nmap("n","e","f")'
    local t = parse(src, { keep_headers = true })
    eq(3, #t.categories)
    eq("a", t.entries[3].category)
  end)

  it("a header right above a map does not swallow the map's comment", function()
    local t = parse(generate.box "A" .. '\n-- note\nmap("n","a","b")', { keep_headers = true })
    eq("-- note", t.entries[1].comment)
  end)
end)

describe("template import: round trip through generate", function()
  it("regenerates the same top-level statements", function()
    local src = table.concat({
      'require "x"',
      "local map = vim.keymap.set",
      "",
      "-- note",
      'map("n", ";", ":", { desc = "CMD" })',
      'map("i", "jk", "<ESC>")',
      "",
      'map({ "n", "x" }, "<leader>q", function()',
      '  require("a").b()',
      'end, { desc = "q" })',
      "",
      "for k in pairs {} do",
      "  map('n', k, 'x')",
      "end",
    }, "\n")
    local out = generate.strip_header(generate.render(parse(src)))
    -- Same text but for the added "Uncategorized" header and spacing.
    local function squash(s)
      return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
    end
    local without_box = out:gsub("%-%- %[Uncategorized%]\n", "")
    eq(
      squash [[require "x" local map = vim.keymap.set -- note map("n", ";", ":", { desc = "CMD" }) map("i", "jk", "<ESC>") map({ "n", "x" }, "<leader>q", function() require("a").b() end, { desc = "q" }) for k in pairs {} do map('n', k, 'x') end]],
      squash(without_box)
    )
  end)

  it("importing generated output gives the same template", function()
    local src = 'local map = vim.keymap.set\nmap("n", "a", "b", { desc = "x" })\n-- c\nmap("i", "d", function() end)\n'
    local t1 = parse(src)
    local t2 = parse(generate.strip_header(generate.render(t1)), { drop_headers = true })
    -- ids are positional and the second pass sees no new entries.
    eq(t1.entries, t2.entries)
    eq(t1.preamble, t2.preamble)
  end)
end)
