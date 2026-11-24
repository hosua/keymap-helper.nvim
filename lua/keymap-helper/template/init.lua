--- The keymap template workflow: import a hand-written mappings file into the
--- template, generate the mappings file back out of it. Every function returns
--- `result, err`: a table on success, nil and a message on failure. Nothing
--- here prints or opens a window; the command and the scripts decide how to
--- show it, and pass `confirm` when a step needs a yes.
local Path = require "plenary.path"
local backup = require "keymap-helper.template.backup"
local generate = require "keymap-helper.template.generate"
local import = require "keymap-helper.template.import"
local json = require "keymap-helper.template.json"
local schema = require "keymap-helper.template.schema"

local M = {}

--- @class KeymapHelperTemplateOpts
--- @field root string|nil config root; relative paths resolve against it (default stdpath("config"))
--- @field template string|nil template path (default config `template.path`)
--- @field target string|nil generated file (default the template's `target`, else config `template.target`)
--- @field backups boolean|nil default config `template.backups`
--- @field keep_headers boolean|nil import: keep the file's box headers as categories
--- @field confirm (fun(message: string): boolean)|nil asked before a risky overwrite; absent means "no"
--- @field now integer|nil epoch seconds, for tests

local function absolute(root, p)
  if vim.startswith(p, "/") or vim.startswith(p, "~") then
    return vim.fn.fnamemodify(p, ":p")
  end
  return root .. "/" .. p
end

--- @param opts KeymapHelperTemplateOpts|nil
--- @return { root: string, template: string, target: string, backups: boolean, template_name: string }
function M.paths(opts)
  opts = opts or {}
  local cfg = require("keymap-helper.config").get().template
  local root = (opts.root or vim.fn.stdpath "config"):gsub("/+$", "")
  local template = absolute(root, opts.template or cfg.path)
  local name = opts.template or cfg.path
  if vim.startswith(template, root .. "/") then
    name = template:sub(#root + 2)
  end
  local backups = opts.backups
  if backups == nil then
    backups = cfg.backups
  end
  return {
    root = root,
    template = template,
    template_name = name,
    target = opts.target and absolute(root, opts.target) or nil,
    default_target = cfg.target,
    backups = backups,
  }
end

--- Read, decode, normalise and validate the template file.
--- @param path string
--- @return table|nil template, string|nil err
function M.load(path)
  local text = generate.read(path)
  if not text then
    return nil, ("no template at %s (run :KeymapHelper import)"):format(path)
  end
  local tpl, err = json.decode(text)
  if not tpl then
    return nil, ("%s is not valid JSON: %s"):format(path, err)
  end
  tpl = schema.normalize(tpl)
  local errs = schema.validate(tpl)
  if #errs > 0 then
    return nil, ("%s is invalid:\n  %s"):format(path, table.concat(errs, "\n  "))
  end
  return tpl
end

--- Write the template JSON, backing up the file it replaces.
--- @return string|nil backup_path, string|nil err
local function save(tpl, path, p, now)
  local errs = schema.validate(tpl)
  if #errs > 0 then
    return nil, "template is invalid, nothing was written:\n  " .. table.concat(errs, "\n  ")
  end
  local bak, err
  if p.backups then
    bak, err = backup.create(path, now)
    if err then
      return nil, err
    end
  end
  local ok, werr = generate.atomic_write(path, json.encode(tpl))
  if not ok then
    return nil, werr
  end
  return bak or ""
end

local function ask(opts, message)
  if not opts.confirm then
    return false, message .. "\n  (needs a yes: pass --yes, or use the :KeymapHelper command)"
  end
  return opts.confirm(message) == true
end

--- Where `generate` writes: an explicit target, else the template's own.
local function target_of(p, tpl)
  return p.target or absolute(p.root, tpl and tpl.target or p.default_target)
end

local function counts(tpl)
  local maps, raw = 0, 0
  for _, e in ipairs(tpl.entries) do
    if e.kind == "map" then
      maps = maps + 1
    else
      raw = raw + 1
    end
  end
  return maps, raw
end

--- Build the template from the mappings file. Does nothing when the template
--- already generates that file. Never touches the mappings file.
--- @param opts KeymapHelperTemplateOpts|nil
--- @return table|nil result { status = "imported"|"in_sync", template, maps, raw, backup? }, string|nil err
function M.import(opts)
  opts = opts or {}
  local p = M.paths(opts)
  local existing, load_err
  if Path:new(p.template):exists() then
    existing, load_err = M.load(p.template)
  end
  local source = target_of(p, existing)
  local disk = generate.read(source)
  if not disk then
    return nil, ("nothing to import: %s does not exist"):format(source)
  end
  if existing then
    local want = generate.render(existing, { target = source, template_name = p.template_name })
    if generate.strip_header(disk) == generate.strip_header(want) then
      local maps, raw = counts(existing)
      return { status = "in_sync", template = p.template, maps = maps, raw = raw }
    end
  end
  if Path:new(p.template):exists() then
    local why = load_err and ("the template is unreadable (%s)"):format(load_err:match "^[^\n]*")
      or (source .. " does not match the template")
    local yes, msg =
      ask(opts, ("%s.\nImport it again and replace %s? The old template is backed up first."):format(why, p.template))
    if not yes then
      return nil, msg or "import cancelled, the template is unchanged"
    end
  end
  local tpl = import.parse(generate.strip_header(disk), {
    keep_headers = opts.keep_headers,
    map_functions = require("keymap-helper.config").get().map_functions,
    header_pattern = require("keymap-helper.config").get().header_pattern,
    target = vim.startswith(source, p.root .. "/") and source:sub(#p.root + 2) or source,
  })
  local bak, err = save(tpl, p.template, p, opts.now)
  if err then
    return nil, err
  end
  local maps, raw = counts(tpl)
  return { status = "imported", template = p.template, maps = maps, raw = raw, backup = bak ~= "" and bak or nil }
end

--- Write the mappings file from the template.
--- @param opts KeymapHelperTemplateOpts|nil
--- @return table|nil result { status = "written"|"unchanged", target, backup? }, string|nil err
function M.generate(opts)
  opts = opts or {}
  local p = M.paths(opts)
  local tpl, err = M.load(p.template)
  if not tpl then
    return nil, err
  end
  local target = target_of(p, tpl)
  local disk = generate.read(target)
  if disk and not generate.has_header(disk) then
    local yes, msg = ask(
      opts,
      ("%s was not generated by keymap-helper (no AUTOGENERATED header).\nOverwrite it? It is backed up first."):format(
        target
      )
    )
    if not yes then
      return nil, msg or "generate cancelled, nothing was written"
    end
  end
  local res, werr =
    generate.write(tpl, target, { backups = p.backups, now = opts.now, template_name = p.template_name })
  if not res then
    return nil, werr
  end
  return { status = res.changed and "written" or "unchanged", target = target, backup = res.backup }
end

--- Whether the file on disk is what the template generates.
--- @param opts KeymapHelperTemplateOpts|nil
--- @return boolean|nil in_sync, string|nil reason (an error when the template cannot be read)
function M.check(opts)
  local p = M.paths(opts)
  local tpl, err = M.load(p.template)
  if not tpl then
    return nil, err
  end
  local target = target_of(p, tpl)
  return generate.check(tpl, target, { template_name = p.template_name })
end

return M
