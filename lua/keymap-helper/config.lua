--- Config: defaults, validation, and the resolved table the rest of the
--- plugin reads. The defaults table below IS the README's config section;
--- keep the two identical.
local M = {}

--- A section is one titled block in the keymap list. Sections are filled in
--- order: a section with `files` claims every map(...) call parsed out of
--- those files, and the first section with `rest = true` gets every live
--- mapping (with a description) that no earlier section claimed.
---
--- @class KeymapHelperSection
--- @field title string
--- @field subtitle string|nil shown after the title, dimmed
--- @field files string[]|nil paths; relative ones resolve against stdpath("config")
--- @field runtime_files string[]|nil looked up on 'runtimepath' (e.g. a plugin's mappings file)
--- @field group_by "header"|"none"|nil "header" splits on box-comment headers in the files
--- @field rest boolean|nil collect every unclaimed live mapping
--- @field collapsed boolean|nil start folded to just the header line (default false)

--- @class KeymapHelperConfig
M.defaults = {
  --- @type KeymapHelperSection[]
  sections = {
    { title = "Your config", subtitle = "lua/mappings.lua", files = { "lua/mappings.lua" }, group_by = "header" },
    { title = "Everything else", subtitle = "every other mapping with a description", rest = true, collapsed = true },
  },
  -- Lua pattern for a section header comment; capture 1 is the header text.
  -- The default matches `-- │ General │` box-drawing headers.
  header_pattern = "^%-%- │%s*(.-)%s*│$",
  -- Function names treated as "set a mapping" when scanning files.
  map_functions = { "map", "vim.keymap.set", "keymap.set" },
  -- Modes whose live mappings feed `rest` sections.
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
  end
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
