--- Config: defaults, validation, and the resolved table the rest of the
--- plugin reads. The defaults table below IS the README's config section;
--- keep the two identical.
local M = {}

--- A section is one titled block in the keymap list. Every visible live map
--- goes to the first section whose matchers all pass (sections with
--- `rest = true` are tried last). A section with no matcher and no `rest`
--- matches nothing. Maps no section matched go to an implicit "Default" section
--- when no section has `rest = true`.
---
--- @class KeymapHelperSection
--- @field title string
--- @field subtitle string|nil shown after the title, dimmed
--- @field files string[]|nil paths; relative ones resolve against stdpath("config"). Claims the maps those files set, in file order
--- @field runtime_files string[]|nil like `files`, looked up on 'runtimepath' (e.g. a plugin's mappings file)
--- @field config boolean|nil maps set by your config
--- @field builtin boolean|nil maps set by Neovim itself
--- @field plugin boolean|string|string[]|nil maps set by any plugin, or by the named plugin(s)
--- @field lhs string|nil Lua pattern matched against the displayed lhs
--- @field desc string|nil Lua pattern matched against the desc ("" when none)
--- @field mode string|string[]|nil only these modes
--- @field fn (fun(map: KeymapHelperMatchMap, origin: KeymapHelperOrigin): boolean)|nil custom matcher
--- @field group_by "header"|"plugin"|"leader_prefix"|"none"|nil default "none"
--- @field rest boolean|nil fallback: takes whatever no other section matched
--- @field collapsed boolean|nil start folded to just the header line (default false)
--- @field hidden boolean|nil claim matching maps but do not show the section

--- @class KeymapHelperConfig
M.defaults = {
  --- @type KeymapHelperSection[]
  sections = {
    { title = "Default", subtitle = "everything else with a description", rest = true, collapsed = false },
  },
  -- Normal-mode key that opens the list, or false for none. A key you already
  -- mapped is never overwritten.
  keymap = "<leader>km",
  -- Show maps with no desc and <Plug> maps (file sections always show their own).
  show_undocumented = false,
  detect = {
    scan_config = true, -- text-scan stdpath("config") *.lua to place string-rhs maps
    max_files = 200, -- stop scanning after this many files (health warns)
    lazy_keys = true, -- read lazy.nvim `keys` specs for plugin names
    which_key = true, -- name <leader>x groups after which-key groups, if loaded
  },
  -- Lua pattern for a section header comment; capture 1 is the header text.
  -- The default matches `-- │ General │` box-drawing headers.
  header_pattern = "^%-%- │%s*(.-)%s*│$",
  -- Function names treated as "set a mapping" when scanning files.
  map_functions = { "map", "vim.keymap.set", "keymap.set" },
  -- Modes whose live mappings are listed (plus any mode a `files` section sets).
  modes = { "n", "i", "v", "x", "t" },
  window = {
    title = " Keymaps ",
    max_width = 96,
    footer = "<CR> toggle section · zR open all · zM close all · q close",
  },
  hint = {
    enabled = true,
    -- `{key}` becomes the key you mapped to :KeymapHelper, or the command itself.
    message = "Type {key} to view a list of all keymappings!",
    timeout_ms = 6000,
    -- "center" or "bottom_right".
    position = "center",
  },
  -- Short "how to read this list" header (leader keys, mode letters).
  intro = { enabled = true, collapsed = false },
}

local resolved

-- Keys a section may carry (see KeymapHelperSection).
local SECTION_KEYS = {}
for _, k in ipairs { "title", "subtitle", "group_by", "rest", "collapsed", "hidden" } do
  SECTION_KEYS[k] = true
end
for _, k in ipairs(require("keymap-helper.match").MATCHER_KEYS) do
  SECTION_KEYS[k] = true
end

--- Section keys no matcher or option reads, reported as "sections[1].colapsed".
local function unknown_section_keys(sections, out)
  for i, s in ipairs(sections) do
    if type(s) == "table" then
      local keys = vim.tbl_keys(s)
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)
      for _, k in ipairs(keys) do
        if not SECTION_KEYS[k] then
          out[#out + 1] = ("sections[%d].%s"):format(i, tostring(k))
        end
      end
    end
  end
  return out
end

--- Collect "a.b.c" paths present in `user` but absent from `defaults`, so a
--- typo in the user's opts is reported instead of silently ignored.
local function unknown_keys(user, defaults, prefix, out)
  for k, v in pairs(user) do
    local path = prefix .. tostring(k)
    if defaults[k] == nil then
      out[#out + 1] = path
    elseif type(v) == "table" and type(defaults[k]) == "table" and not vim.islist(defaults[k]) then
      unknown_keys(v, defaults[k], path .. ".", out)
    end
  end
  return out
end

local GROUP_BY = { header = true, plugin = true, leader_prefix = true, none = true }

--- @param cfg KeymapHelperConfig
local function validate(cfg)
  vim.validate("sections", cfg.sections, "table")
  for i, s in ipairs(cfg.sections) do
    local name = ("sections[%d]"):format(i)
    vim.validate(name .. ".title", s.title, "string")
    vim.validate(name .. ".files", s.files, "table", true)
    vim.validate(name .. ".runtime_files", s.runtime_files, "table", true)
    vim.validate(name .. ".rest", s.rest, "boolean", true)
    vim.validate(name .. ".collapsed", s.collapsed, "boolean", true)
    vim.validate(name .. ".hidden", s.hidden, "boolean", true)
    vim.validate(name .. ".config", s.config, "boolean", true)
    vim.validate(name .. ".builtin", s.builtin, "boolean", true)
    vim.validate(name .. ".plugin", s.plugin, { "boolean", "string", "table" }, true)
    vim.validate(name .. ".lhs", s.lhs, "string", true)
    vim.validate(name .. ".desc", s.desc, "string", true)
    vim.validate(name .. ".subtitle", s.subtitle, "string", true)
    vim.validate(name .. ".mode", s.mode, { "string", "table" }, true)
    vim.validate(name .. ".fn", s.fn, "function", true)
    vim.validate(name .. ".group_by", s.group_by, function(v)
      return v == nil or GROUP_BY[v] == true
    end, "one of: header, plugin, leader_prefix, none")
  end
  vim.validate("keymap", cfg.keymap, function(v)
    return v == false or (type(v) == "string" and v ~= "")
  end, "a key such as <leader>km, or false")
  vim.validate("show_undocumented", cfg.show_undocumented, "boolean")
  vim.validate("detect.max_files", cfg.detect.max_files, function(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
  end, "a positive integer")
  vim.validate("header_pattern", cfg.header_pattern, "string")
  vim.validate("modes", cfg.modes, "table")
  vim.validate("hint.message", cfg.hint.message, "string")
  vim.validate("hint.position", cfg.hint.position, function(v)
    return v == "center" or v == "bottom_right"
  end, "one of: center, bottom_right")
end

--- @param opts table|nil
--- @return KeymapHelperConfig cfg, string[] unknown
function M.resolve(opts)
  opts = opts or {}
  local unknown = unknown_keys(opts, M.defaults, "", {})
  if type(opts.sections) == "table" then
    unknown_section_keys(opts.sections, unknown)
  end
  -- Lists (sections, modes, ...) replace the default wholesale rather than
  -- merging index by index, which would splice two unrelated lists together.
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  for _, key in ipairs { "sections", "modes", "map_functions" } do
    if opts[key] ~= nil then
      merged[key] = vim.deepcopy(opts[key])
    end
  end
  validate(merged)
  resolved = merged
  if #unknown > 0 then
    vim.notify("keymap-helper: unknown config key(s): " .. table.concat(unknown, ", "), vim.log.levels.WARN)
  end
  return resolved, unknown
end

--- @return KeymapHelperConfig
function M.get()
  return resolved or M.resolve()
end

return M
