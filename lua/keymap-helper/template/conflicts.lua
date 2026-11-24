--- Who defines which key, in the order the definitions take effect. Pure: it
--- takes the list of keymap events a scratch nvim recorded and groups them.
---
--- An event is { op = "set"|"del", mode, lhs, source, desc?, summary?, buffer? }.
--- `lhs` is canonical (what keytrans() prints), `source` is `default:<name>`,
--- `template:<entry id>`, `template:raw`, `plugin:<name>` or `config:<file>`.
--- Buffer-local events are skipped: only global maps can shadow each other.
---
--- Per (mode, lhs) the result lists every definition still standing after the
--- deletes, oldest first, and the last one wins. Deleted definitions move to
--- `removed`. A key is reported when the template defines it twice
--- (`duplicate`), when something else defined it first (`override`), or when
--- a delete took a definition away (`removed`).
local M = {}

--- The concrete modes a `vim.keymap.set` mode argument stands for.
--- @param mode string|string[]
--- @return string[]
function M.modes(mode)
  local out, seen = {}, {}
  local function add(m)
    if not seen[m] then
      seen[m] = true
      out[#out + 1] = m
    end
  end
  local list = type(mode) == "table" and mode or { mode }
  for _, m in ipairs(list) do
    if m == "" then
      for _, c in ipairs { "n", "x", "s", "o" } do
        add(c)
      end
    elseif m == "v" then
      add "x"
      add "s"
    elseif m == "!" then
      add "i"
      add "c"
    else
      for c in m:gmatch "." do
        add(c)
      end
    end
  end
  return out
end

--- @param source string
--- @return boolean
function M.is_template(source)
  return source:sub(1, 9) == "template:"
end

local function copy_def(ev)
  return { source = ev.source, desc = ev.desc, summary = ev.summary }
end

--- @param events table[]
--- @return { keys: table[], counts: { duplicates: integer, overrides: integer, removed: integer } }
function M.build(events)
  local by_key, order = {}, {}
  for _, ev in ipairs(events) do
    if not ev.buffer then
      local id = ev.mode .. "\0" .. ev.lhs
      local k = by_key[id]
      if not k then
        k = { mode = ev.mode, lhs = ev.lhs, defs = {}, removed = {} }
        by_key[id] = k
        order[#order + 1] = k
      end
      if ev.op == "set" then
        k.defs[#k.defs + 1] = copy_def(ev)
      else
        for _, d in ipairs(k.defs) do
          d.by = ev.source
          k.removed[#k.removed + 1] = d
        end
        k.defs = {}
      end
    end
  end

  local keys = {}
  local counts = { duplicates = 0, overrides = 0, removed = 0 }
  for _, k in ipairs(order) do
    local templates, seen_other, override = 0, false, false
    for _, d in ipairs(k.defs) do
      if M.is_template(d.source) then
        templates = templates + 1
        override = override or seen_other
      else
        seen_other = true
      end
    end
    local duplicate = templates >= 2
    local removed = #k.removed > 0
    if duplicate or override or removed then
      local winner = k.defs[#k.defs]
      if winner then
        winner.wins = true
        for _, d in ipairs(k.defs) do
          if d ~= winner then
            d.shadowed_by = winner.source
          end
        end
      end
      counts.duplicates = counts.duplicates + (duplicate and 1 or 0)
      counts.overrides = counts.overrides + (override and 1 or 0)
      counts.removed = counts.removed + (removed and 1 or 0)
      keys[#keys + 1] = {
        mode = k.mode,
        lhs = k.lhs,
        duplicate = duplicate,
        override = override,
        defs = k.defs,
        removed = k.removed,
      }
    end
  end
  return { keys = keys, counts = counts }
end

return M
