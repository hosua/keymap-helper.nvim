--- Lua source -> template. Reads the file with the treesitter Lua parser.
---
--- Only top-level `map(...)` / `vim.keymap.set(...)` calls whose arguments are
--- plain enough to model become `map` entries. Everything else (the
--- `require`, local helpers, `for` loops that create maps, a call whose modes
--- or lhs are variables, an options table we cannot read) stays a `raw`
--- entry at its original position, so nothing is dropped.
local schema = require "keymap-helper.template.schema"

local M = {}

--- @class KeymapHelperImportOpts
--- @field drop_headers boolean|nil ignore the file's category headers, everything is uncategorized (default false: headers become categories)
--- @field keep_headers boolean|nil legacy switch, `false` means the same as `drop_headers`
--- @field header_pattern string|nil one-line header pattern, capture 1 is the title (default `-- [Title]`)
--- @field map_functions string[]|nil call names read as "set a mapping"
--- @field target string|nil `target` written into the template

local function node_text(node, src)
  return vim.treesitter.get_node_text(node, src)
end

--- Value of a Lua string literal node, or nil when the node is not one.
local function string_value(node, src)
  if node:type() ~= "string" then
    return nil
  end
  local chunk = load("return " .. node_text(node, src), "=string", "t", {})
  if not chunk then
    return nil
  end
  local ok, v = pcall(chunk)
  return ok and type(v) == "string" and v or nil
end

--- Fields of a table constructor as { key = node } (named) or a list (positional).
--- Returns nil when the table has comments, bracket keys or both kinds.
local function table_fields(node)
  local keyed, positional = {}, {}
  for c in node:iter_children() do
    if c:named() then
      if c:type() ~= "field" then
        return nil
      end
      local name = c:field("name")[1]
      if name then
        if name:type() ~= "identifier" then
          return nil
        end
        keyed[#keyed + 1] = { name = name, value = c:field("value")[1] }
      else
        positional[#positional + 1] = c:named_child(0)
      end
    end
  end
  if #keyed > 0 and #positional > 0 then
    return nil
  end
  return keyed, positional
end

local function read_modes(node, src)
  local s = string_value(node, src)
  if s then
    return { s }
  end
  if node:type() ~= "table_constructor" then
    return nil
  end
  local keyed, positional = table_fields(node)
  if not keyed or #keyed > 0 or #positional == 0 then
    return nil
  end
  local modes = {}
  for _, n in ipairs(positional) do
    local m = string_value(n, src)
    if not m then
      return nil
    end
    modes[#modes + 1] = m
  end
  return modes
end

--- A literal value that fits the option's JSON type, or nil.
local function literal(node, src)
  local t = node:type()
  if t == "true" then
    return true
  elseif t == "false" then
    return false
  elseif t == "number" then
    return tonumber(node_text(node, src))
  end
  return string_value(node, src)
end

--- @return table|nil opts, table|nil opts_raw
local function read_opts(node, src)
  if node:type() ~= "table_constructor" then
    return nil
  end
  local keyed, positional = table_fields(node)
  if not keyed or #positional > 0 then
    return nil
  end
  local opts, raw = {}, {}
  for _, f in ipairs(keyed) do
    local key = node_text(f.name, src)
    if opts[key] ~= nil or raw[key] ~= nil then
      return nil
    end
    local v = literal(f.value, src)
    local types = schema.OPT_TYPES[key]
    if v ~= nil and types and vim.tbl_contains(types, type(v)) then
      opts[key] = v
    else
      raw[key] = node_text(f.value, src)
    end
  end
  return opts, raw
end

--- The map fields for a call node, or nil when it is not a plain map call.
--- @return table|nil
local function read_map(node, src, fns)
  if node:type() ~= "function_call" then
    return nil
  end
  local name, args_node = node:field("name")[1], node:field("arguments")[1]
  if not name or not args_node then
    return nil
  end
  local call = node_text(name, src)
  local first = args_node:child(0)
  if not vim.tbl_contains(fns, call) or not first or first:type() ~= "(" then
    return nil
  end
  local args = {}
  for c in args_node:iter_children() do
    if c:named() then
      if c:type() == "comment" then
        return nil
      end
      args[#args + 1] = c
    end
  end
  if #args < 3 or #args > 4 then
    return nil
  end
  local modes, lhs = read_modes(args[1], src), string_value(args[2], src)
  if not modes or not lhs or lhs == "" then
    return nil
  end
  local e = { kind = "map", modes = modes, lhs = lhs }
  local rhs = string_value(args[3], src)
  if rhs then
    e.rhs = rhs
  else
    e.lua = node_text(args[3], src)
  end
  if args[4] then
    local opts, raw = read_opts(args[4], src)
    if not opts then
      return nil
    end
    e.opts = next(opts) and opts or nil
    e.opts_raw = next(raw) and raw or nil
  end
  if call ~= schema.DEFAULT_CALL then
    e.call = call
  end
  return e
end

--- Split a run of comment lines into plain comment pieces and category headers.
--- @param lines string[] the run's lines
--- @param first_row integer row (0-based) of the first line
--- @return table[] pieces { type = "comment"|"header", s, e, text?, title? }
local function split_run(lines, first_row, header_pattern)
  local pieces, cur = {}, nil
  local function flush(last)
    if cur then
      cur.e = first_row + last - 1
      cur.text = table.concat(lines, "\n", cur.i, last)
      pieces[#pieces + 1] = cur
      cur = nil
    end
  end
  local box = require("keymap-helper.scan").LEGACY_BOX
  local function is_top(l)
    return l and vim.startswith(l, "-- ┌") and vim.endswith(l, "┐")
  end
  local function is_bottom(l)
    return l and vim.startswith(l, "-- └") and vim.endswith(l, "┘")
  end
  local i = 1
  while i <= #lines do
    local title = is_top(lines[i]) and is_bottom(lines[i + 2]) and lines[i + 1]:match(box)
    local width = 3
    if not title then
      title, width = lines[i]:match(header_pattern), 1
    end
    if title then
      flush(i - 1)
      pieces[#pieces + 1] = { type = "header", s = first_row + i - 1, e = first_row + i + width - 2, title = title }
      i = i + width
    else
      cur = cur or { type = "comment", s = first_row + i - 1, i = i }
      i = i + 1
    end
  end
  flush(#lines)
  return pieces
end

--- Statements and comments in file order, comments attached to the statement
--- right below them (`lead`) or on the same line after it (`trail`).
local function collect_items(root, src, lines, header_pattern)
  local items, run = {}, nil
  local function flush_run()
    if run then
      local run_lines = vim.list_slice(lines, run.s + 1, run.e + 1)
      for _, p in ipairs(split_run(run_lines, run.s, header_pattern)) do
        items[#items + 1] = p
      end
      run = nil
    end
  end
  for child in root:iter_children() do
    local sr, _, er = child:range()
    if child:type() == "comment" then
      local last = items[#items]
      if not run and last and last.type == "stmt" and last.e == sr and not last.trail then
        last.trail = node_text(child, src)
      elseif run and sr == run.e + 1 then
        run.e = er
      else
        flush_run()
        run = { s = sr, e = er }
      end
    else
      flush_run()
      local item = { type = "stmt", node = child, s = sr, e = er }
      local last = items[#items]
      if last and last.type == "comment" and last.e == sr - 1 then
        item.lead = last.text
        item.s = last.s
        items[#items] = nil
      end
      items[#items + 1] = item
    end
  end
  flush_run()
  return items
end

--- @param src string the Lua file's text
--- @param opts KeymapHelperImportOpts|nil
--- @return table template
function M.parse(src, opts)
  opts = opts or {}
  local fns = opts.map_functions or { "map", "vim.keymap.set", "keymap.set" }
  local header_pattern = opts.header_pattern or "^%-%- %[(.-)%]%s*$"
  local tpl = schema.new(opts.target)
  local root = vim.treesitter.get_string_parser(src, "lua"):parse()[1]:root()
  local lines = vim.split(src, "\n", { plain = true })
  local items = collect_items(root, src, lines, header_pattern)

  local keep = not opts.drop_headers and opts.keep_headers ~= false
  local by_title, current, n = {}, schema.UNCATEGORIZED, 0
  local preamble_open = true
  local function next_id()
    n = n + 1
    return ("e%03d"):format(n)
  end
  local function add_raw(text)
    if preamble_open then
      tpl.preamble[#tpl.preamble + 1] = text
    else
      tpl.entries[#tpl.entries + 1] = { id = next_id(), kind = "raw", category = current, text = text }
    end
  end

  for _, it in ipairs(items) do
    if it.type == "header" then
      if keep then
        preamble_open = false
        local id = by_title[it.title]
        if not id then
          id = schema.slug(it.title)
          local taken = vim.tbl_filter(function(c)
            return c.id == id
          end, tpl.categories)
          if #taken > 0 then
            id = id .. "-" .. (#tpl.categories + 1)
          end
          by_title[it.title] = id
          tpl.categories[#tpl.categories + 1] = { id = id, title = it.title }
        end
        current = id
      end
    elseif it.type == "comment" then
      add_raw(it.text)
    else
      local e = read_map(it.node, src, fns)
      if e then
        preamble_open = false
        e.id, e.category = next_id(), current
        e.comment, e.trailing = it.lead, it.trail
        tpl.entries[#tpl.entries + 1] = e
      else
        local text = node_text(it.node, src)
        if it.lead then
          text = it.lead .. "\n" .. text
        end
        if it.trail then
          text = text .. " " .. it.trail
        end
        add_raw(text)
      end
    end
  end
  return tpl
end

return M
