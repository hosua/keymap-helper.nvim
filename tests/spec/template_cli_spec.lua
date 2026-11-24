local cli = require "keymap-helper.template.cli"
local commands = require "keymap-helper.commands"

local ROOT = "/x/keymap-helper.nvim"

describe("template cli", function()
  it("parses flags with = and with a separate value", function()
    local a = assert(cli.parse("generate", { "--root=/r", "--target", "t.lua", "--check", "-y" }))
    eq({ root = "/r", target = "t.lua", check = true, yes = true }, a)
  end)

  it("maps --no-backup and --keep-headers to underscore keys", function()
    local a = assert(cli.parse("import", { "--keep-headers", "--no-backup" }))
    eq({ keep_headers = true, no_backup = true }, a)
  end)

  it("rejects a flag the command does not have, a missing value and a bad choice", function()
    eq("unknown option --check", select(2, cli.parse("import", { "--check" })))
    eq("--root needs a value", select(2, cli.parse("import", { "--root" })))
    ok(select(2, cli.parse("import", { "--completion=tcsh" })):find("must be one of", 1, true))
    eq("--yes takes no value", select(2, cli.parse("import", { "--yes=1" })))
  end)

  it("help follows the USAGE / OPTIONS / EXAMPLES layout, plain without a terminal", function()
    local h = cli.help("generate", ROOT, false)
    ok(
      vim.startswith(
        h,
        "USAGE\n  $ kh-generate [OPTIONS]\n\nwrite the mappings file from the keymap template\n\nOPTIONS\n"
      )
    )
    ok(h:find("\nEXAMPLES\n", 1, true))
    ok(not h:find("\27", 1, true))
    ok(
      h:find(
        "--completion=bash > ~/.local/share/bash-completion/completions/_keymap-helper.nvim-kh-generate.bash",
        1,
        true
      )
    )
    ok(h:find("--check", 1, true))
    ok(cli.help("import", ROOT, true):find("\27[1mUSAGE\27[0m", 1, true))
  end)

  it("the bash completion parses and completes flags and values", function()
    local text = cli.completion("generate", "bash", ROOT)
    local f = tmpdir() .. "/c.bash"
    vim.fn.writefile(vim.split(text, "\n"), f)
    eq(0, vim.system({ "bash", "-n", f }):wait().code)
    local script = ([[source %s; COMP_WORDS=(kh-generate --ch); COMP_CWORD=1; _keymap_helper_nvim_kh_generate; printf '%%s\n' "${COMPREPLY[@]}"]]):format(
      f
    )
    local out = vim.system({ "bash", "-c", script }, { text = true }):wait()
    eq("--check\n", out.stdout)
    script = ([[source %s; COMP_WORDS=(kh-generate --completion ""); COMP_CWORD=2; _keymap_helper_nvim_kh_generate; printf '%%s\n' "${COMPREPLY[@]}"]]):format(
      f
    )
    eq("bash\nzsh\nfish\n", vim.system({ "bash", "-c", script }, { text = true }):wait().stdout)
  end)

  it("the zsh and fish completions parse where the shell is installed", function()
    local dir = tmpdir()
    for _, shell in ipairs { "zsh", "fish" } do
      local text = cli.completion("import", shell, ROOT)
      ok(text:find("kh-import", 1, true))
      ok(text:find("keep-headers", 1, true))
      if vim.fn.executable(shell) == 1 then
        local f = ("%s/c.%s"):format(dir, shell)
        vim.fn.writefile(vim.split(text, "\n"), f)
        eq(0, vim.system({ shell, "-n", f }):wait().code, shell .. " rejected its completion")
      end
    end
    eq(nil, cli.completion("import", "tcsh", ROOT))
  end)
end)

describe(":KeymapHelper import / generate wiring", function()
  it("has both subcommands and completes their words", function()
    ok(commands.subcommands.import and commands.subcommands.generate)
    eq({ "import" }, commands.complete("im", "KeymapHelper im", 0))
    eq({ "generate" }, commands.complete("gen", "KeymapHelper gen", 0))
    eq({ "keep_headers" }, commands.complete("k", "KeymapHelper import k", 0))
    eq({ "check" }, commands.complete("", "KeymapHelper generate ", 0))
    eq({}, commands.complete("", "KeymapHelper show x y", 0))
  end)

  it("reports an unknown word instead of ignoring it", function()
    local seen
    local notify = vim.notify
    vim.notify = function(msg)
      seen = msg
    end
    commands.subcommands.import({ "keep" }, true)
    vim.notify = notify
    ok(seen and seen:find("import takes drop_headers", 1, true), tostring(seen))
  end)
end)

describe("confirm message wrapping", function()
  local root = "/cfg/nvim"
  local msg = table.concat({
    "This file does not match the template:",
    "  " .. root .. "/lua/mappings.lua",
    "Import it again and replace the template? The old template is backed up first, so nothing is lost.",
    "  " .. root .. "/lua/mappings.template.json",
  }, "\n")

  it("puts each path on its own shortened line and wraps long prose", function()
    local lines = commands.wrap(msg, 40, root)
    ok(vim.tbl_contains(lines, "  lua/mappings.lua"), vim.inspect(lines))
    ok(vim.tbl_contains(lines, "  lua/mappings.template.json"), vim.inspect(lines))
    for _, l in ipairs(lines) do
      ok(vim.fn.strdisplaywidth(l) <= 40, ("too wide: %q"):format(l))
    end
    ok(table.concat(lines, " "):find("backed up first", 1, true), "the warning survives the wrap")
  end)

  it("shortens the home directory when the path is outside the root", function()
    local home = vim.uv.os_homedir()
    eq({ "  ~/x/y.lua" }, commands.wrap("  " .. home .. "/x/y.lua", 40, "/other"))
  end)

  it("keeps the tail of a path wider than the popup", function()
    local lines = commands.wrap("  /a/very/long/path/that/cannot/fit/mappings.template.json", 24, nil)
    eq(1, #lines)
    ok(vim.fn.strdisplaywidth(lines[1]) <= 24, lines[1])
    ok(lines[1]:find("…", 1, true) and lines[1]:find("template.json", 1, true), lines[1])
  end)
end)

describe("kh-template cli", function()
  it("takes one command word and the shared flags", function()
    local a = assert(cli.parse("template", { "preview", "--keep-headers", "--root=/r" }))
    eq({ sub = "preview", keep_headers = true, root = "/r" }, a)
  end)

  it("rejects an unknown command, a second command and flags it does not have", function()
    ok(select(2, cli.parse("template", { "bogus" })):find("unknown command bogus", 1, true))
    ok(select(2, cli.parse("template", { "show", "save" })):find("unexpected argument", 1, true))
    eq("unknown option --yes", select(2, cli.parse("template", { "--yes" })))
    eq("unknown option --json", select(2, cli.parse("template", { "--json" })))
  end)

  it("import and generate accept --json", function()
    eq({ json = true }, assert(cli.parse("import", { "--json" })))
    eq({ json = true }, assert(cli.parse("generate", { "--json" })))
  end)

  it("help lists the three commands in a COMMANDS section", function()
    local h = cli.help("template", ROOT, false)
    ok(h:find("\nCOMMANDS\n  show ", 1, true))
    ok(h:find("  $ kh-template save [OPTIONS] < plan.json", 1, true))
  end)
end)
