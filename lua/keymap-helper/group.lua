--- Rows and groups for one section. Pure: merges the same map seen in
--- several modes into one row, then splits rows into titled groups.
local M = {}

--- @class KeymapHelperItem
--- @field modes string[]
--- @field lhs string display form
--- @field desc string
--- @field group string|nil file header or origin.group
--- @field order integer|nil file position or origin.order
--- @field plugin string|nil

M.MODE_ORDER = { n = 1, i = 2, v = 3, x = 4, s = 5, o = 6, t = 7, c = 8, l = 9 }

local UNKNOWN_RANK = 100
local LEADER = "<leader>"
local OTHER_KEYS = "Other keys"

local function mode_less(a, b)
  local ra, rb = M.MODE_ORDER[a] or UNKNOWN_RANK, M.MODE_ORDER[b] or UNKNOWN_RANK
  if ra ~= rb then
    return ra < rb
  end
  return a < b
end

--- Deduped, ordered, comma-joined mode letters: { "x", "n" } -> "n,x".
--- @param modes string[]
--- @return string
function M.mode_list(modes)
  local seen, list = {}, {}
  for _, m in ipairs(modes) do
    if not seen[m] then
      seen[m] = true
      table.insert(list, m)
    end
  end
  table.sort(list, mode_less)
  return table.concat(list, ",")
end

--- "<leader>gb" -> "<leader>g"; "<leader>q" -> "<leader>"; non-leader -> nil.
--- @param lhs string
--- @return string|nil
function M.leader_prefix(lhs)
  if lhs:sub(1, #LEADER) ~= LEADER then
    return nil
  end
  local rest = lhs:sub(#LEADER + 1)
  local token = rest:match "^<[^>]+>" or rest:match "^[%z\1-\127\194-\244][\128-\191]*"
  if not token then
    return nil
  end
  if token == rest then
    return LEADER
  end
  return LEADER .. token
end

--- Same lhs + desc + group (in one section) become one item with all modes.
--- @param items KeymapHelperItem[]
--- @return KeymapHelperItem[]
function M.merge(items)
  local out, by_key = {}, {}
  for _, it in ipairs(items) do
    local key = table.concat({ it.lhs, it.desc, it.group or "\0" }, "\1")
    local cur = by_key[key]
    if not cur then
      cur = vim.tbl_extend("force", {}, it, { modes = {} })
      by_key[key] = cur
      table.insert(out, cur)
    elseif it.order and (not cur.order or it.order < cur.order) then
      cur.order = it.order
    end
    for _, m in ipairs(it.modes) do
      if not vim.tbl_contains(cur.modes, m) then
        table.insert(cur.modes, m)
      end
    end
  end
  for _, it in ipairs(out) do
    table.sort(it.modes, mode_less)
  end
  return out
end

local function order_of(it)
  return it.order or math.huge
end

--- Sort by file order, then lhs, then modes.
local function item_less(a, b)
  local oa, ob = order_of(a), order_of(b)
  if oa ~= ob then
    return oa < ob
  end
  if a.lhs ~= b.lhs then
    return a.lhs < b.lhs
  end
  return M.mode_list(a.modes) < M.mode_list(b.modes)
end

local function rows_of(items)
  local sorted = vim.list_slice(items, 1, #items)
  table.sort(sorted, item_less)
  local rows = {}
  for _, it in ipairs(sorted) do
    table.insert(rows, { modes = M.mode_list(it.modes), lhs = it.lhs, desc = it.desc })
  end
  return rows
end

local function min_order(items)
  local best = math.huge
  for _, it in ipairs(items) do
    best = math.min(best, order_of(it))
  end
  return best
end

--- Split into { title, items } buckets keyed by `title_of(item)`, in first-seen order.
local function bucket(items, title_of)
  local buckets, by_title = {}, {}
  for _, it in ipairs(items) do
    local title = title_of(it)
    local b = by_title[title]
    if not b then
      b = { title = title, items = {} }
      by_title[title] = b
      table.insert(buckets, b)
    end
    table.insert(b.items, it)
  end
  return buckets
end

local function to_groups(buckets)
  local groups = {}
  for _, b in ipairs(buckets) do
    table.insert(groups, { title = b.title, rows = rows_of(b.items) })
  end
  return groups
end

local function leader_groups(items, wk_groups)
  local buckets = bucket(items, function(it)
    return M.leader_prefix(it.lhs) or OTHER_KEYS
  end)
  -- Titles are keyed by prefix while bucketing, then decorated for display.
  table.sort(buckets, function(a, b)
    local function rank(t)
      if t == LEADER then
        return 0
      elseif t == OTHER_KEYS then
        return 2
      end
      return 1
    end
    if rank(a.title) ~= rank(b.title) then
      return rank(a.title) < rank(b.title)
    end
    return a.title < b.title
  end)
  for _, b in ipairs(buckets) do
    local name = wk_groups[b.title]
    if b.title ~= LEADER and b.title ~= OTHER_KEYS and name then
      b.title = b.title .. "  " .. name
    end
  end
  return to_groups(buckets)
end

--- @param items KeymapHelperItem[]
--- @param group_by "header"|"plugin"|"leader_prefix"|"none"
--- @param wk_groups table<string, string>
--- @return KeymapHelperGroup[]
function M.build(items, group_by, wk_groups)
  if #items == 0 then
    return {}
  end
  wk_groups = wk_groups or {}

  if group_by == "header" then
    local with, without = {}, {}
    for _, it in ipairs(items) do
      table.insert(it.group and with or without, it)
    end
    local buckets = bucket(with, function(it)
      return it.group
    end)
    table.sort(buckets, function(a, b)
      local ma, mb = min_order(a.items), min_order(b.items)
      if ma ~= mb then
        return ma < mb
      end
      return a.title < b.title
    end)
    local groups = to_groups(buckets)
    vim.list_extend(groups, leader_groups(without, wk_groups))
    return groups
  elseif group_by == "plugin" then
    local buckets = bucket(items, function(it)
      return it.plugin or "Other"
    end)
    table.sort(buckets, function(a, b)
      local la, lb = a.title:lower(), b.title:lower()
      if la ~= lb then
        return la < lb
      end
      return a.title < b.title
    end)
    return to_groups(buckets)
  elseif group_by == "leader_prefix" then
    return leader_groups(items, wk_groups)
  end
  return { { rows = rows_of(items) } }
end

return M
