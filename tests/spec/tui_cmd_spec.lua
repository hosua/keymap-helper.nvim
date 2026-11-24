local tui = require "keymap-helper.tui"
local commands = require "keymap-helper.commands"

describe("edit command", function()
  it("builds the bun command line from the paths it is given", function()
    eq(
      {
        "/usr/bin/bun",
        "run",
        "/p/tui/src/index.tsx",
        "--root=/c",
        "--template=t.json",
        "--analysis=/tmp/a",
        "--result=/tmp/r",
      },
      tui.argv {
        bun = "/usr/bin/bun",
        plugin_root = "/p",
        root = "/c",
        template = "t.json",
        analysis = "/tmp/a",
        result = "/tmp/r",
      }
    )
    eq({ "bun", "run", "/p/tui/src/index.tsx", "--root=/c" }, tui.argv { bun = "bun", plugin_root = "/p", root = "/c" })
  end)

  it("is a subcommand and completes", function()
    ok(commands.subcommands.edit)
    ok(vim.tbl_contains(commands.complete("ed", "KeymapHelper ed", 0), "edit"))
  end)

  it("finds the plugin root", function()
    ok(vim.uv.fs_stat(tui.plugin_root() .. "/tui/src/index.tsx"))
  end)
end)
