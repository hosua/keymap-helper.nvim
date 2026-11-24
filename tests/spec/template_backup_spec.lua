local backup = require "keymap-helper.template.backup"

local T = os.time { year = 2026, month = 11, day = 24, hour = 9, min = 15, sec = 2 }

describe("template backup", function()
  it("names the backup mappings_<YYYY_MM_DD_hh:mm:ss>.bak next to the file", function()
    eq("2026_11_24_09:15:02", backup.stamp(T))
    eq(
      "/c/lua/mappings_2026_11_24_09:15:02.bak",
      backup.path_for("/c/lua/mappings.lua", T, function()
        return false
      end)
    )
  end)

  it("appends _1, _2 on a same-second collision", function()
    local taken = {
      ["/c/lua/mappings_2026_11_24_09:15:02.bak"] = true,
      ["/c/lua/mappings_2026_11_24_09:15:02_1.bak"] = true,
    }
    eq(
      "/c/lua/mappings_2026_11_24_09:15:02_2.bak",
      backup.path_for("/c/lua/mappings.lua", T, function(p)
        return taken[p]
      end)
    )
  end)

  it("takes the stem without the last extension", function()
    eq("mappings", backup.stem "/x/mappings.lua")
    eq("mappings.template", backup.stem "/x/mappings.template.json")
  end)

  it("copies the file and never overwrites a backup", function()
    local dir = tmpdir()
    local target = dir .. "/mappings.lua"
    vim.fn.writefile({ "one" }, target)
    local a = assert(backup.create(target, T))
    vim.fn.writefile({ "two" }, target)
    local b = assert(backup.create(target, T))
    ok(a ~= b)
    eq({ "one" }, vim.fn.readfile(a))
    eq({ "two" }, vim.fn.readfile(b))
    eq(dir .. "/mappings_2026_11_24_09:15:02_1.bak", b)
  end)

  it("does nothing when there is no file yet", function()
    eq(nil, (backup.create(tmpdir() .. "/missing.lua", T)))
  end)

  it("lists backups newest first and ignores other files", function()
    local dir = tmpdir()
    for _, n in ipairs {
      "mappings_2026_11_24_09:15:02.bak",
      "mappings_2026_11_25_10:00:00.bak",
      "mappings.lua",
      "mappings.template_2026_11_26_10:00:00.bak",
      "notes.bak",
    } do
      vim.fn.writefile({ "x" }, dir .. "/" .. n)
    end
    local got = vim.tbl_map(vim.fs.basename, backup.list(dir .. "/mappings.lua"))
    eq({ "mappings_2026_11_25_10:00:00.bak", "mappings_2026_11_24_09:15:02.bak" }, got)
  end)
end)
