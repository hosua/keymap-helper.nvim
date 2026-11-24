-- Import -> generate on a copy of a real mappings.lua (tests/fixtures/user_mappings.lua),
-- then the same keymaps must exist when both files are loaded in a fresh nvim.
-- Run by `make integration` inside a throwaway XDG tree: nothing here touches a real config.
local real = vim.fn.expand "~/.local/share/nvim"
local data_dir = vim.fn.stdpath "data"
if data_dir == real or vim.startswith(data_dir, real .. "/") then
  error("refusing to run: stdpath('data') is the real " .. real .. " (use `make integration`)")
end

local template = require "keymap-helper.template"
local generate = require "keymap-helper.template.generate"
local json = require "keymap-helper.template.json"

local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h:h")
local FIXTURE = plugin .. "/tests/fixtures/user_mappings.lua"

--- A throwaway config root holding a copy of the fixture.
local function config_root()
  local root = tmpdir()
  vim.fn.mkdir(root .. "/lua", "p")
  vim.fn.writefile(vim.fn.readfile(FIXTURE), root .. "/lua/mappings.lua")
  return root
end

--- Global keymaps a file creates, loaded in a child nvim with no config.
local function keymaps(file)
  local res = vim
    .system(
      { vim.v.progpath, "--headless", "-u", "NONE", "-l", plugin .. "/tests/integration/dump_keymaps.lua", file },
      { text = true }
    )
    :wait()
  eq(0, res.code, res.stderr)
  return vim.json.decode(res.stdout)
end

local function list(dir, pattern)
  return vim.tbl_map(vim.fs.basename, vim.fn.glob(dir .. "/" .. pattern, false, true))
end

describe("template round trip on a copy of a real mappings.lua", function()
  it("imports every top-level map and keeps the rest", function()
    local root = config_root()
    local res = assert(template.import { root = root })
    eq("imported", res.status)
    eq(96, res.maps)
    ok(res.raw > 0)
    local tpl = assert(template.load(root .. "/lua/mappings.template.json"))
    eq("uncategorized", tpl.categories[1].id)
    eq(1, #tpl.categories)
    ok(tpl.preamble[1]:find("nvchad.mappings", 1, true))
  end)

  it("generates a file whose keymaps match the original's", function()
    local root = config_root()
    assert(template.import { root = root })
    local out = root .. "/generated/mappings.lua"
    local res = assert(template.generate { root = root, target = out })
    eq("written", res.status)
    local before, after = keymaps(FIXTURE), keymaps(out)
    ok(#before > 90, "the original defines keymaps")
    eq(before, after)
  end)

  it("also matches with the original headers kept as categories", function()
    local root = config_root()
    assert(template.import { root = root, keep_headers = true })
    local tpl = assert(template.load(root .. "/lua/mappings.template.json"))
    ok(#tpl.categories > 3, "headers became categories")
    local out = root .. "/generated/mappings.lua"
    assert(template.generate { root = root, target = out })
    eq(keymaps(FIXTURE), keymaps(out))
    -- The generated headers are the ones group_by = "header" reads.
    local titles = {}
    for _, c in ipairs(tpl.categories) do
      titles[c.title] = true
    end
    ok(titles.General and titles.Splits)
    local text = table.concat(vim.fn.readfile(out), "\n")
    ok(text:find("-- │ General ", 1, true))
  end)

  it("generate twice gives the same file and one backup", function()
    local root = config_root()
    assert(template.import { root = root })
    local target = root .. "/lua/mappings.lua"
    local original = vim.fn.readfile(target)
    local first = assert(template.generate {
      root = root,
      confirm = function()
        return true
      end,
    })
    eq("written", first.status)
    eq(original, vim.fn.readfile(first.backup), "the backup holds the old file")
    local text = table.concat(vim.fn.readfile(target), "\n")
    local second = assert(template.generate { root = root })
    eq("unchanged", second.status)
    eq(text, table.concat(vim.fn.readfile(target), "\n"))
    eq(1, #list(root .. "/lua", "mappings_*.bak"))
    -- And the generated file is now the one import calls in sync.
    eq("in_sync", assert(template.import { root = root }).status)
    eq(true, (template.check { root = root }))
  end)

  it("refuses to overwrite a hand-written target without a yes", function()
    local root = config_root()
    assert(template.import { root = root })
    local target = root .. "/lua/mappings.lua"
    local res, err = template.generate { root = root }
    eq(nil, res)
    ok(err:find("needs a yes", 1, true), err)
    eq(vim.fn.readfile(FIXTURE), vim.fn.readfile(target))
    eq({}, list(root .. "/lua", "mappings_*.bak"))
    eq(nil, (template.generate {
      root = root,
      confirm = function()
        return false
      end,
    }))
    eq(vim.fn.readfile(FIXTURE), vim.fn.readfile(target))
  end)

  it("an invalid template aborts before the backup and the write", function()
    local root = config_root()
    assert(template.import { root = root })
    local path = root .. "/lua/mappings.template.json"
    local tpl = json.decode(table.concat(vim.fn.readfile(path), "\n"))
    tpl.entries[1].lhs = ""
    vim.fn.writefile(vim.split(json.encode(tpl), "\n"), path)
    local res, err = template.generate {
      root = root,
      confirm = function()
        return true
      end,
    }
    eq(nil, res)
    ok(err:find("lhs must be a non-empty string", 1, true), err)
    eq(vim.fn.readfile(FIXTURE), vim.fn.readfile(root .. "/lua/mappings.lua"))
    eq({}, list(root .. "/lua", "*.bak"))
  end)

  it("re-importing a drifted file backs up the template and asks first", function()
    local root = config_root()
    assert(template.import { root = root })
    assert(template.generate {
      root = root,
      confirm = function()
        return true
      end,
    })
    -- Someone edits the generated file by hand.
    local target = root .. "/lua/mappings.lua"
    local lines = vim.fn.readfile(target)
    lines[#lines + 1] = 'vim.keymap.set("n", "<leader>zzz", "<cmd>echo 1<CR>", { desc = "added by hand" })'
    vim.fn.writefile(lines, target)
    local res, err = template.import { root = root }
    eq(nil, res)
    ok(err:find("does not match the template", 1, true), err)
    local imported = assert(template.import {
      root = root,
      confirm = function()
        return true
      end,
    })
    eq("imported", imported.status)
    eq(97, imported.maps)
    eq(1, #list(root .. "/lua", "mappings.template_*.bak"))
    -- The edited file still has no AUTOGENERATED header, so it is not "in sync" until generated.
    eq(false, (template.check { root = root }))
  end)

  it("honours backups = false", function()
    local root = config_root()
    assert(template.import { root = root })
    assert(template.generate {
      root = root,
      backups = false,
      confirm = function()
        return true
      end,
    })
    eq({}, list(root .. "/lua", "*.bak"))
  end)
end)

describe("kh-import and kh-generate scripts", function()
  local function run(script, args)
    local cmd = { plugin .. "/scripts/" .. script }
    vim.list_extend(cmd, args)
    local res = vim.system(cmd, { text = true, stdin = false }):wait()
    return res.code, res.stdout, res.stderr
  end

  it("import, generate, then --check exits 0; an edit makes --check exit 1", function()
    local root = config_root()
    local code, out = run("kh-import", { "--root=" .. root })
    eq(0, code, out)
    ok(out:find("imported 96 maps", 1, true), out)
    code, out = run("kh-generate", { "--root=" .. root, "--yes" })
    eq(0, code, out)
    ok(out:find("backup: lua/mappings_", 1, true), out)
    eq(0, (run("kh-generate", { "--root=" .. root, "--check" })))
    vim.fn.writefile({ "-- edited" }, root .. "/lua/mappings.lua")
    local c, _, err = run("kh-generate", { "--root=" .. root, "--check" })
    eq(1, c)
    ok(err:find("differs from what the template generates", 1, true), err)
  end)

  it("exit 2 when a yes is needed and there is no terminal", function()
    local root = config_root()
    eq(0, (run("kh-import", { "--root=" .. root })))
    local code, _, err = run("kh-generate", { "--root=" .. root })
    eq(2, code)
    ok(err:find("--yes", 1, true), err)
    eq(vim.fn.readfile(FIXTURE), vim.fn.readfile(root .. "/lua/mappings.lua"))
  end)

  it("exit 2 on an unknown option, and --help prints the layout", function()
    local code, _, err = run("kh-generate", { "--nope" })
    eq(2, code)
    ok(err:find("try `kh-generate --help`", 1, true), err)
    local hcode, out = run("kh-generate", { "--help" })
    eq(0, hcode)
    ok(out:find "^USAGE\n  %$ kh%-generate", out)
    ok(out:find("\nOPTIONS\n", 1, true) and out:find("\nEXAMPLES\n", 1, true))
  end)
end)
