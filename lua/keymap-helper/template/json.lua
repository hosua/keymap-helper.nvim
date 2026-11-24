--- Reads and writes the template JSON. Writing is deterministic (fixed key
--- order, one key per line) so the file diffs cleanly, and multi-line source
--- text is written as an array of lines so it can be edited by hand.
local M = {}

local ORDER = {
  "version",
  "target",
  "preamble",
  "categories",
  "entries",
  "id",
  "kind",
  "category",
  "title",
  "subtitle",
  "modes",
  "lhs",
  "rhs",
  "lua",
  "opts",
  "opts_raw",
  "comment",
  "trailing",
  "call",
  "text",
  "desc",
  "silent",
  "expr",
  "remap",
  "noremap",
  "buffer",
  "nowait",
  "unique",
  "script",
  "replace_keycodes",
}
local RANK = {}
for i, k in ipairs(ORDER) do
  RANK[k] = i
end

-- Keys that always hold a list, so an empty one is written as [] and not {}.
local LISTS = { preamble = true, categories = true, entries = true, modes = true }
-- Keys whose string value is written as an array of lines when it has newlines.
local MULTILINE = { lua = true, comment = true, trailing = true, text = true }
-- Objects short enough to sit on one line.
local INLINE = { opts = true, opts_raw = true }
local INLINE_MAX = 100

local function sorted_keys(t)
  local keys = vim.tbl_keys(t)
  table.sort(keys, function(a, b)
    local ra, rb = RANK[a] or math.huge, RANK[b] or math.huge
    if ra ~= rb then
      return ra < rb
    end
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function scalar(v)
  -- vim.json.encode does not escape "/", so the output stays readable.
  return vim.json.encode(v)
end

local function is_scalar(v)
  return type(v) ~= "table"
end

local encode

--- @return string|nil one-line form, when it is short and flat
local function inline(v, key)
  if type(v) ~= "table" then
    return scalar(v)
  end
  local parts = {}
  if LISTS[key] or vim.islist(v) and next(v) ~= nil then
    for _, x in ipairs(v) do
      if not is_scalar(x) or (type(x) == "string" and x:find("\n", 1, true)) then
        return nil
      end
      parts[#parts + 1] = scalar(x)
    end
    return "[" .. table.concat(parts, ", ") .. "]"
  end
  if next(v) == nil then
    return "{}"
  end
  for _, k in ipairs(sorted_keys(v)) do
    if not is_scalar(v[k]) or (type(v[k]) == "string" and v[k]:find("\n", 1, true)) then
      return nil
    end
    parts[#parts + 1] = scalar(tostring(k)) .. ": " .. scalar(v[k])
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

--- @param v any
--- @param depth integer
--- @param key string|nil key this value sits under
--- @param parent string|nil key of the container holding that key
function encode(v, depth, key, parent)
  if type(v) == "string" and (MULTILINE[key] or parent == "preamble") and v:find("\n", 1, true) then
    v = vim.split(v, "\n", { plain = true })
    key = nil
  end
  if type(v) ~= "table" then
    return scalar(v)
  end
  local pad = ("  "):rep(depth + 1)
  local close = ("  "):rep(depth)
  local one = (INLINE[key] or parent == "categories" or LISTS[key] and key == "modes") and inline(v, key) or nil
  if one and #one <= INLINE_MAX then
    return one
  end
  local out = {}
  if vim.islist(v) and (next(v) ~= nil or LISTS[key]) then
    if next(v) == nil then
      return "[]"
    end
    for _, x in ipairs(v) do
      out[#out + 1] = pad .. encode(x, depth + 1, nil, key)
    end
    return "[\n" .. table.concat(out, ",\n") .. "\n" .. close .. "]"
  end
  if next(v) == nil then
    return LISTS[key] and "[]" or "{}"
  end
  for _, k in ipairs(sorted_keys(v)) do
    out[#out + 1] = pad .. scalar(tostring(k)) .. ": " .. encode(v[k], depth + 1, k, key)
  end
  return "{\n" .. table.concat(out, ",\n") .. "\n" .. close .. "}"
end

--- @param tpl table
--- @return string
function M.encode(tpl)
  return encode(tpl, 0) .. "\n"
end

--- @param text string
--- @return table|nil value, string|nil err
function M.decode(text)
  local ok, res = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if not ok then
    return nil, tostring(res)
  end
  return res
end

return M
