--- The template's shape: constants, a fresh empty template, normalising text
--- fields, and validation. Validation never throws and never reads a file, so
--- generate can refuse a bad template before it touches anything.
---
--- Template (version 1):
---   version    1
---   target     path of the generated file, relative to the config root
---   preamble   string[]   raw Lua chunks written before the first entry
---   categories { id, title, subtitle? }[]   "uncategorized" must exist
---   entries    entry[]    written in this order
---
--- An entry is one of:
---   { id, kind = "map", category, modes = string[], lhs, rhs | lua,
---     opts?, opts_raw?, comment?, trailing?, call? }
---   { id, kind = "raw", category, text }
--- `rhs` is a string mapping target. `lua` is Lua source written as-is (a
--- function or any expression). `opts` holds the typed vim.keymap.set options,
--- `opts_raw` holds the others as Lua source text, key by key. `comment` is the
--- comment lines written above the call, `trailing` a comment after it, `call`
--- the function name to emit (default "map"). Keys that start with "_" belong
--- to other tools and are kept but ignored here.
local M = {}

M.VERSION = 1
M.UNCATEGORIZED = "uncategorized"
M.DEFAULT_CALL = "map"

--- Typed option keys, in the order they are written.
M.OPT_ORDER =
  { "desc", "silent", "expr", "remap", "noremap", "buffer", "nowait", "unique", "script", "replace_keycodes" }
M.OPT_TYPES = {
  desc = { "string" },
  silent = { "boolean" },
  expr = { "boolean" },
  remap = { "boolean" },
  noremap = { "boolean" },
  buffer = { "boolean", "number" },
  nowait = { "boolean" },
  unique = { "boolean" },
  script = { "boolean" },
  replace_keycodes = { "boolean" },
}

--- Fields that hold Lua text and may be written as a string or a list of lines.
M.TEXT_FIELDS = { "lua", "comment", "trailing", "text" }

local ENTRY_KEYS = {
  id = true,
  kind = true,
  category = true,
  modes = true,
  lhs = true,
  rhs = true,
  lua = true,
  opts = true,
  opts_raw = true,
  comment = true,
  trailing = true,
  call = true,
  text = true,
}

--- @param title string
--- @return string
function M.slug(title)
  local s = title:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  return s ~= "" and s or "category"
end

--- @param target string|nil
--- @return table
function M.new(target)
  return {
    version = M.VERSION,
    target = target or "lua/mappings.lua",
    preamble = {},
    categories = { { id = M.UNCATEGORIZED, title = "Uncategorized" } },
    entries = {},
  }
end

local function join(v)
  if type(v) == "table" and vim.islist(v) then
    for _, line in ipairs(v) do
      if type(line) ~= "string" then
        return v
      end
    end
    return table.concat(v, "\n")
  end
  return v
end

--- Returns a copy with every text field a string. Lists of lines (how the
--- JSON file stores multi-line text) are joined with newlines.
--- @param tpl table
--- @return table
function M.normalize(tpl)
  local out = vim.deepcopy(tpl)
  if type(out.preamble) == "table" then
    for i, v in ipairs(out.preamble) do
      out.preamble[i] = join(v)
    end
  end
  if type(out.entries) == "table" then
    for _, e in ipairs(out.entries) do
      if type(e) == "table" then
        for _, f in ipairs(M.TEXT_FIELDS) do
          if e[f] ~= nil then
            e[f] = join(e[f])
          end
        end
      end
    end
  end
  return out
end

local function type_ok(v, types)
  return vim.tbl_contains(types, type(v))
end

local function check_entry(e, i, cats, seen, errs)
  local at = ("entries[%d]"):format(i)
  local function err(msg)
    errs[#errs + 1] = at .. ": " .. msg
  end
  if type(e) ~= "table" then
    return err "must be an object"
  end
  if type(e.id) ~= "string" or e.id == "" then
    err "id must be a non-empty string"
  elseif seen[e.id] then
    err(("id %q is used twice"):format(e.id))
  else
    seen[e.id] = true
    at = ("entries[%d] (%s)"):format(i, e.id)
  end
  for k in pairs(e) do
    if not ENTRY_KEYS[k] and not (type(k) == "string" and k:sub(1, 1) == "_") then
      errs[#errs + 1] = ("%s: unknown key %q"):format(at, tostring(k))
    end
  end
  if not cats[e.category] then
    errs[#errs + 1] = ("%s: category %q is not in categories"):format(at, tostring(e.category))
  end
  if e.kind == "raw" then
    if type(e.text) ~= "string" then
      errs[#errs + 1] = at .. ": a raw entry needs `text`"
    end
    return
  end
  if e.kind ~= "map" then
    errs[#errs + 1] = ('%s: kind must be "map" or "raw", got %s'):format(at, vim.inspect(e.kind))
    return
  end
  local function e2(msg)
    errs[#errs + 1] = at .. ": " .. msg
  end
  if type(e.modes) ~= "table" or not vim.islist(e.modes) or #e.modes == 0 then
    e2 "modes must be a non-empty list of mode strings"
  else
    for _, m in ipairs(e.modes) do
      if type(m) ~= "string" then
        e2 "modes must hold strings only"
        break
      end
    end
  end
  if type(e.lhs) ~= "string" or e.lhs == "" then
    e2 "lhs must be a non-empty string"
  end
  if (e.rhs == nil) == (e.lua == nil) then
    e2 "set exactly one of `rhs` (string) and `lua` (Lua source)"
  elseif e.rhs ~= nil and type(e.rhs) ~= "string" then
    e2 "rhs must be a string"
  elseif e.lua ~= nil and (type(e.lua) ~= "string" or e.lua:match "^%s*$") then
    e2 "lua must be non-empty Lua source"
  end
  for _, f in ipairs { "comment", "trailing" } do
    if e[f] ~= nil and type(e[f]) ~= "string" then
      e2(f .. " must be a string")
    end
  end
  if e.call ~= nil and (type(e.call) ~= "string" or not e.call:match "^[%a_][%w_.]*$") then
    e2 "call must be a function name such as map or vim.keymap.set"
  end
  if e.opts ~= nil then
    if type(e.opts) ~= "table" then
      e2 "opts must be an object"
    else
      for k, v in pairs(e.opts) do
        if not M.OPT_TYPES[k] then
          e2(("opts.%s is not a typed option (put it in opts_raw)"):format(tostring(k)))
        elseif not type_ok(v, M.OPT_TYPES[k]) then
          e2(("opts.%s must be %s"):format(k, table.concat(M.OPT_TYPES[k], " or ")))
        end
      end
    end
  end
  if e.opts_raw ~= nil then
    if type(e.opts_raw) ~= "table" then
      e2 "opts_raw must be an object"
    else
      for k, v in pairs(e.opts_raw) do
        if type(k) ~= "string" or not k:match "^[%a_][%w_]*$" then
          e2(("opts_raw key %s is not a plain name"):format(vim.inspect(k)))
        elseif type(v) ~= "string" or v == "" then
          e2(("opts_raw.%s must be Lua source text"):format(k))
        elseif e.opts and e.opts[k] ~= nil then
          e2(("option %s is in both opts and opts_raw"):format(k))
        end
      end
    end
  end
end

--- @param tpl any a normalized template
--- @return string[] errors empty when valid
function M.validate(tpl)
  local errs = {}
  if type(tpl) ~= "table" then
    return { "template must be a JSON object" }
  end
  if tpl.version ~= M.VERSION then
    errs[#errs + 1] = ("version must be %d, got %s (this keymap-helper cannot read it)"):format(
      M.VERSION,
      vim.inspect(tpl.version)
    )
    return errs
  end
  if type(tpl.target) ~= "string" or tpl.target == "" then
    errs[#errs + 1] = "target must be a path string"
  end
  if type(tpl.preamble) ~= "table" then
    errs[#errs + 1] = "preamble must be a list of strings"
  else
    for i, v in ipairs(tpl.preamble) do
      if type(v) ~= "string" then
        errs[#errs + 1] = ("preamble[%d] must be a string"):format(i)
      end
    end
  end
  local cats = {}
  if type(tpl.categories) ~= "table" then
    errs[#errs + 1] = "categories must be a list"
  else
    for i, c in ipairs(tpl.categories) do
      local at = ("categories[%d]"):format(i)
      if type(c) ~= "table" or type(c.id) ~= "string" or c.id == "" then
        errs[#errs + 1] = at .. ": needs a string id"
      elseif cats[c.id] then
        errs[#errs + 1] = ("%s: id %q is used twice"):format(at, c.id)
      else
        cats[c.id] = true
        if type(c.title) ~= "string" or c.title == "" then
          errs[#errs + 1] = ("%s (%s): title must be a non-empty string"):format(at, c.id)
        elseif vim.fn.strdisplaywidth(c.title) > 70 or c.title:find "\n" then
          errs[#errs + 1] = ("%s (%s): title must be one line of at most 70 columns"):format(at, c.id)
        end
        if c.subtitle ~= nil and (type(c.subtitle) ~= "string" or c.subtitle:find "\n") then
          errs[#errs + 1] = ("%s (%s): subtitle must be a one-line string"):format(at, c.id)
        end
      end
    end
    if not cats[M.UNCATEGORIZED] then
      errs[#errs + 1] = ('categories must include id "%s"'):format(M.UNCATEGORIZED)
    end
  end
  if type(tpl.entries) ~= "table" then
    errs[#errs + 1] = "entries must be a list"
  else
    local seen = {}
    for i, e in ipairs(tpl.entries) do
      check_entry(e, i, cats, seen, errs)
    end
  end
  return errs
end

return M
