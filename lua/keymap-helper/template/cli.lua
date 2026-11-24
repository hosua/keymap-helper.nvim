--- Command line for scripts/kh-import and scripts/kh-generate. They run under
--- `nvim -l`, so the scripts and :KeymapHelper share one implementation.
---
--- Exit codes: 0 done (or in sync), 1 failed (or `--check` found a difference),
--- 2 usage error or a step that needs a yes and had no terminal to ask.
local M = {}

local COMMON = {
  {
    long = "--root",
    value = "dir",
    arg = "DIR",
    desc = "config root, relative paths resolve against it (default: stdpath config)",
  },
  { long = "--template", value = "file", arg = "FILE", desc = "template path (default: lua/mappings.template.json)" },
  { long = "--target", value = "file", arg = "FILE", desc = "mappings file (default: the template's target)" },
  { long = "--no-backup", desc = "do not keep a .bak copy before overwriting" },
  { short = "-y", long = "--yes", desc = "answer yes to the overwrite question" },
  {
    long = "--completion",
    value = "shell",
    arg = "SHELL",
    choices = { "bash", "zsh", "fish" },
    desc = "print the shell completion script",
  },
  { short = "-h", long = "--help", desc = "show this help" },
}

local SPECS = {
  import = {
    summary = "build the keymap template from a mappings file",
    flags = {
      { long = "--keep-headers", desc = "keep the file's box headers as categories (default: all uncategorized)" },
    },
    examples = {
      { "kh-import --root=$HOME/.config/nvim", "imported 96 maps and 21 raw blocks into lua/mappings.template.json" },
      { "kh-import --keep-headers --yes" },
    },
  },
  generate = {
    summary = "write the mappings file from the keymap template",
    flags = { { long = "--check", desc = "write nothing, exit 1 when the file differs from the template" } },
    examples = {
      {
        "kh-generate --root=$HOME/.config/nvim",
        "wrote lua/mappings.lua (backup: lua/mappings_2026_11_24_09:15:02.bak)",
      },
      { "kh-generate --check" },
    },
  },
}

local function flags_of(cmd)
  local all = vim.deepcopy(SPECS[cmd].flags)
  vim.list_extend(all, vim.deepcopy(COMMON))
  return all
end
M.flags_of = flags_of

local function repo_name(plugin_root)
  return vim.fs.basename(plugin_root)
end

local function snake(s)
  return (s:gsub("[^%w_]", "_"))
end

--- @param cmd string "import"|"generate"
--- @param plugin_root string
--- @return string
function M.help(cmd, plugin_root, color)
  local spec = SPECS[cmd]
  local name = "kh-" .. cmd
  local bold, reset = "", ""
  if color then
    bold, reset = "\27[1m", "\27[0m"
  end
  local flags = flags_of(cmd)
  local labels, width = {}, 0
  for i, f in ipairs(flags) do
    local l = f.short and (f.short .. ", " .. f.long) or ("    " .. f.long)
    if f.arg then
      l = l .. "=" .. f.arg
    end
    labels[i] = l
    width = math.max(width, #l)
  end
  local repo = repo_name(plugin_root)
  local stem = ("_%s-%s"):format(repo, name)
  local out = {
    bold .. "USAGE" .. reset,
    "  $ " .. name .. " [OPTIONS]",
    "",
    spec.summary,
    "",
    bold .. "OPTIONS" .. reset,
  }
  for i, f in ipairs(flags) do
    out[#out + 1] = ("  %-" .. width .. "s  %s"):format(labels[i], f.desc)
  end
  out[#out + 1] = ""
  out[#out + 1] = bold .. "EXAMPLES" .. reset
  for i, ex in ipairs(spec.examples) do
    if i > 1 then
      out[#out + 1] = ""
    end
    out[#out + 1] = "  $ " .. ex[1]
    if ex[2] then
      out[#out + 1] = "  " .. ex[2]
    end
  end
  vim.list_extend(out, {
    "",
    "  # bash (needs the ~/.bashrc loop once, then open a new shell)",
    ("  $ %s --completion=bash > ~/.local/share/bash-completion/completions/%s.bash"):format(name, stem),
    "  # zsh (needs ~/.zsh/completions on fpath)",
    ("  $ %s --completion=zsh > ~/.zsh/completions/%s.zsh"):format(name, stem),
    "  # fish",
    ("  $ %s --completion=fish > ~/.config/fish/conf.d/%s.fish"):format(name, stem),
  })
  return table.concat(out, "\n") .. "\n"
end

--- @param cmd string
--- @param shell string
--- @param plugin_root string
--- @return string|nil text
function M.completion(cmd, shell, plugin_root)
  local name = "kh-" .. cmd
  local flags = flags_of(cmd)
  local out = {}
  if shell == "bash" then
    local fn = "_" .. snake(repo_name(plugin_root)) .. "_" .. snake(name)
    local words, dirs, files = {}, {}, {}
    for _, f in ipairs(flags) do
      words[#words + 1] = f.long
      if f.short then
        words[#words + 1] = f.short
      end
      if f.value == "dir" then
        dirs[#dirs + 1] = f.long
      elseif f.value == "file" then
        files[#files + 1] = f.long
      end
    end
    out = {
      fn .. "() {",
      "    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}",
      '    case "${prev}" in',
      ('        %s) mapfile -t COMPREPLY < <(compgen -d -- "${cur}"); return ;;'):format(table.concat(dirs, "|")),
      ('        %s) mapfile -t COMPREPLY < <(compgen -f -- "${cur}"); return ;;'):format(table.concat(files, "|")),
      '        --completion) mapfile -t COMPREPLY < <(compgen -W "bash zsh fish" -- "${cur}"); return ;;',
      "    esac",
      ('    mapfile -t COMPREPLY < <(compgen -W "%s" -- "${cur}")'):format(table.concat(words, " ")),
      "}",
      ("complete -F %s %s"):format(fn, name),
    }
  elseif shell == "zsh" then
    out = { "#compdef " .. name, "", "_arguments \\" }
    for _, f in ipairs(flags) do
      local desc = f.desc:gsub("[%[%]']", "")
      local action = ""
      if f.value == "dir" then
        action = ":dir:_files -/"
      elseif f.value == "file" then
        action = ":file:_files"
      elseif f.value == "shell" then
        action = ":shell:(bash zsh fish)"
      end
      local names = f.short and ("{%s,%s}"):format(f.short, f.long) or f.long
      out[#out + 1] = ("  '%s[%s]%s' \\"):format(names, desc, action):gsub("^  '({.-})", "  %1'")
    end
    out[#out] = out[#out]:gsub(" \\$", "")
  elseif shell == "fish" then
    for _, f in ipairs(flags) do
      local line = ("complete -c %s -l %s"):format(name, f.long:sub(3))
      if f.short then
        line = line .. " -s " .. f.short:sub(2)
      end
      if f.value == "shell" then
        line = line .. " -r -f -a 'bash zsh fish'"
      elseif f.value == "dir" then
        line = line .. " -r -a '(__fish_complete_directories)'"
      elseif f.value == "file" then
        line = line .. " -r -F"
      end
      out[#out + 1] = line .. (" -d '%s'"):format((f.desc:gsub("'", "")))
    end
  else
    return nil
  end
  return table.concat(out, "\n") .. "\n"
end

--- @return table|nil parsed, string|nil err
function M.parse(cmd, argv)
  local by_long, by_short = {}, {}
  for _, f in ipairs(flags_of(cmd)) do
    by_long[f.long] = f
    if f.short then
      by_short[f.short] = f
    end
  end
  local out = {}
  local i = 1
  while i <= #argv do
    local a = argv[i]
    local name, inline = a:match "^(%-%-[%w-]+)=(.*)$"
    local f = by_long[name or a] or by_short[a]
    if not f then
      return nil, ("unknown option %s"):format(a)
    end
    local key = f.long:sub(3):gsub("-", "_")
    if f.value then
      local v = inline
      if v == nil then
        i = i + 1
        v = argv[i]
      end
      if v == nil or v == "" then
        return nil, ("%s needs a value"):format(f.long)
      end
      if f.choices and not vim.tbl_contains(f.choices, v) then
        return nil, ("%s must be one of: %s"):format(f.long, table.concat(f.choices, ", "))
      end
      out[key] = v
    else
      if inline then
        return nil, ("%s takes no value"):format(f.long)
      end
      out[key] = true
    end
    i = i + 1
  end
  return out
end

--- Put plenary and popup on the runtimepath when the script runs without a config.
--- @param plugin_root string
function M.bootstrap(plugin_root)
  vim.opt.runtimepath:prepend(plugin_root)
  local data = vim.fn.stdpath "data"
  local function find(name, env, probe)
    -- A plain list: an unset env var must not end ipairs early.
    local candidates = {
      data .. "/lazy/" .. name,
      vim.fn.expand("~/.local/share/nvim/lazy/" .. name),
      vim.fs.dirname(plugin_root) .. "/" .. name,
      plugin_root .. "/.tests/" .. name,
    }
    if vim.env[env] and vim.env[env] ~= "" then
      table.insert(candidates, 1, vim.env[env])
    end
    for _, p in ipairs(candidates) do
      if vim.uv.fs_stat(p .. probe) then
        vim.opt.runtimepath:append(p)
        return true
      end
    end
    return false
  end
  return find("plenary.nvim", "PLENARY_DIR", "/lua/plenary/path.lua")
end

local function ask_terminal(message)
  io.stdout:write(message .. "\nAre you sure you wish to continue? [y/N] ")
  io.stdout:flush()
  local ans = io.read "*l"
  return ans ~= nil and ans:lower():match "^y" ~= nil
end

--- @param cmd string "import"|"generate"
--- @param argv string[]
--- @param plugin_root string
--- @return integer exit code
function M.run(cmd, argv, plugin_root)
  local name = "kh-" .. cmd
  local args, err = M.parse(cmd, argv)
  if not args then
    io.stderr:write(("%s: %s\ntry `%s --help`\n"):format(name, err, name))
    return 2
  end
  if args.help then
    io.stdout:write(M.help(cmd, plugin_root, vim.uv.guess_handle(1) == "tty" and not vim.env.NO_COLOR))
    return 0
  end
  if args.completion then
    io.stdout:write(M.completion(cmd, args.completion, plugin_root))
    return 0
  end
  if not M.bootstrap(plugin_root) then
    io.stderr:write(name .. ": plenary.nvim not found. Set PLENARY_DIR to its checkout.\n")
    return 1
  end
  local tpl = require "keymap-helper.template"
  local interactive = vim.uv.guess_handle(0) == "tty"
  local opts = {
    root = args.root,
    template = args.template,
    target = args.target,
    keep_headers = args.keep_headers,
    backups = (args.no_backup and false) or nil,
    confirm = (args.yes and function()
      return true
    end) or (interactive and ask_terminal) or nil,
  }
  if cmd == "generate" and args.check then
    local ok, reason = tpl.check(opts)
    if ok then
      return 0
    end
    io.stderr:write(name .. ": " .. (reason or "out of sync") .. "\n")
    return 1
  end
  local res, e = tpl[cmd](opts)
  if not res then
    io.stderr:write(name .. ": " .. e .. "\n")
    return (e:find("needs a yes", 1, true) and 2) or 1
  end
  io.stdout:write(require("keymap-helper.template.report").line(cmd, res, opts.root) .. "\n")
  return 0
end

return M
