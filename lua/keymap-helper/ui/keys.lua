--- The keys bound inside the list. float.lua binds from this table and the
--- footer is generated from it, so the footer can never name a key that is
--- not bound. Not configurable on purpose.
local M = {}

--- @class KeymapHelperListKey
--- @field keys string[] every key that triggers it
--- @field label string footer wording
--- @field desc string mapping desc

--- @type table<string, KeymapHelperListKey>
M.ACTIONS = {
  toggle = { keys = { "<CR>", "za", "<Tab>" }, label = "toggle section", desc = "toggle section" },
  open = { keys = { "l" }, label = "open section", desc = "open section" },
  close = { keys = { "h" }, label = "close section", desc = "close section" },
  open_all = { keys = { "zR" }, label = "open all", desc = "open all sections" },
  close_all = { keys = { "zM" }, label = "close all", desc = "close all sections" },
  quit = { keys = { "q", "<Esc>" }, label = "close", desc = "close keymap list" },
}

-- Footer order; the first key of each action is the one shown.
local FOOTER = { "toggle", "open_all", "close_all", "quit" }

--- "<CR> toggle section · zR open all · zM close all · q close"
--- @return string
function M.footer()
  local parts = {}
  for _, name in ipairs(FOOTER) do
    local a = M.ACTIONS[name]
    parts[#parts + 1] = a.keys[1] .. " " .. a.label
  end
  return table.concat(parts, " · ")
end

return M
