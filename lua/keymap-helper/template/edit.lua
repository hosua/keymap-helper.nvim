--- What the terminal UI reads and writes: a JSON-friendly view of the
--- template, and a plan (category list plus entry order) that is applied to
--- the template on disk. The UI never sends entries back, only ids, so a bug
--- there cannot corrupt an entry and fields it does not know survive a save.
---
--- Plan:
---   categories  { id, title, new? }[]   every category that should exist; a
---               `new` one carries a temporary id and gets its real id here
---   order       { id, category }[]      every entry id exactly once, in the
---               order to write them, with the (possibly temporary) category id
---   delete      string[]?               ids of map entries to drop. They must not
---               appear in `order`. Raw entries cannot be deleted here
local generate = require "keymap-helper.template.generate"
local schema = require "keymap-helper.template.schema"

local M = {}

--- The template as the UI shows it, with the exact Lua line of every map.
--- @param tpl table valid, normalized
--- @return table
function M.view(tpl)
  local calls = {}
  for _, e in ipairs(tpl.entries) do
    if e.kind == "map" then
      calls[e.id] = generate.map_call(e)
    end
  end
  return {
    version = tpl.version,
    categories = tpl.categories,
    entries = tpl.entries,
    calls = calls,
  }
end

--- First free id for a new category: its slug, then slug-2, slug-3 and so on.
local function fresh_id(title, taken)
  local base = schema.slug(title)
  local id, n = base, 1
  while taken[id] do
    n = n + 1
    id = ("%s-%d"):format(base, n)
  end
  taken[id] = true
  return id
end

--- Resolve the plan's categories against the template's.
--- @return table|nil categories, table|nil remap (plan id -> real id), string|nil err
local function resolve_categories(tpl, plan)
  local known = {}
  for _, c in ipairs(tpl.categories) do
    known[c.id] = c
  end
  -- Ids of categories that stay; ids of deleted ones are free to reuse.
  local taken, seen = {}, {}
  for _, c in ipairs(plan.categories) do
    if type(c) ~= "table" or type(c.id) ~= "string" or type(c.title) ~= "string" then
      return nil, nil, "every plan category needs a string id and title"
    end
    if seen[c.id] then
      return nil, nil, ("category %q is in the plan twice"):format(c.id)
    end
    seen[c.id] = true
    if not c.new then
      if not known[c.id] then
        return nil, nil, ("category %q is not in the template"):format(c.id)
      end
      taken[c.id] = true
    end
  end
  if not seen[schema.UNCATEGORIZED] then
    return nil, nil, "the plan must keep the uncategorized category"
  end
  local cats, remap = {}, {}
  for _, c in ipairs(plan.categories) do
    if c.new then
      local id = fresh_id(c.title, taken)
      remap[c.id] = id
      cats[#cats + 1] = { id = id, title = c.title }
    else
      local copy = vim.deepcopy(known[c.id])
      copy.title = c.title
      remap[c.id] = c.id
      cats[#cats + 1] = copy
    end
  end
  return cats, remap
end

--- @param tpl table valid, normalized
--- @param plan table
--- @return table|nil new_template, string|nil err
function M.apply_plan(tpl, plan)
  if type(plan) ~= "table" or type(plan.categories) ~= "table" or type(plan.order) ~= "table" then
    return nil, "the plan needs `categories` and `order`"
  end
  local cats, remap, cerr = resolve_categories(tpl, plan)
  if not cats then
    return nil, cerr
  end
  local out = vim.deepcopy(tpl)
  out.categories = cats

  local by_id = {}
  for _, e in ipairs(tpl.entries) do
    by_id[e.id] = e
  end
  out.entries = {}
  local placed = {}
  for _, id in ipairs(plan.delete or {}) do
    local e = by_id[id]
    if not e then
      return nil, ("the plan deletes an entry that is not in the template: %s"):format(vim.inspect(id))
    end
    if e.kind ~= "map" then
      return nil, ("entry %s is raw Lua and cannot be deleted from here"):format(id)
    end
    placed[id] = "deleted"
  end
  for _, item in ipairs(plan.order) do
    local e = type(item) == "table" and by_id[item.id]
    if not e then
      return nil, ("the plan names an entry that is not in the template: %s"):format(vim.inspect(item and item.id))
    end
    if placed[item.id] == "deleted" then
      return nil, ("entry %s is both deleted and placed in the plan"):format(item.id)
    end
    if placed[item.id] then
      return nil, ("entry %s is in the plan twice"):format(item.id)
    end
    placed[item.id] = true
    local cat = remap[item.category]
    if not cat then
      return nil, ("entry %s goes to category %s, which is not in the plan"):format(item.id, vim.inspect(item.category))
    end
    local copy = vim.deepcopy(e)
    copy.category = cat
    out.entries[#out.entries + 1] = copy
  end
  for id in pairs(by_id) do
    if not placed[id] then
      return nil, ("the plan leaves out entry %s, nothing was written"):format(id)
    end
  end
  local errs = schema.validate(out)
  if #errs > 0 then
    return nil, "the plan makes an invalid template:\n  " .. table.concat(errs, "\n  ")
  end
  return out
end

return M
