--- :checkhealth keymap-helper
local M = {}

function M.check()
  local h = vim.health
  h.start "keymap-helper"
  if vim.fn.has "nvim-0.11" == 1 then
    h.ok("Neovim " .. tostring(vim.version()))
  else
    h.error "Neovim >= 0.11 is required"
  end
  -- Which copy is loaded matters when a dev checkout and a lazy clone coexist.
  local src = debug.getinfo(require("keymap-helper").setup, "S").source:gsub("^@", "")
  h.info("loaded from " .. vim.fn.fnamemodify(src, ":~"))
  local key = require("keymap-helper.collect").command_key()
  if key then
    h.ok("opens with " .. key)
  else
    h.info("no key is mapped to :KeymapHelper", { "set `keymap` in setup(), or map one yourself" })
  end

  h.start "keymap-helper: sections"
  local cfg = require("keymap-helper.config").get()
  local model = require "keymap-helper.model"
  local match = require "keymap-helper.match"
  for _, s in ipairs(cfg.sections) do
    local has_matcher = false
    for _, k in ipairs(match.MATCHER_KEYS) do
      if s[k] ~= nil and s[k] ~= false then
        has_matcher = true
      end
    end
    if not has_matcher and not s.rest then
      h.warn(("%s: no matcher and not `rest`, so it will always be empty"):format(s.title), {
        "add one of: " .. table.concat(match.MATCHER_KEYS, ", ") .. ", or `rest = true`",
      })
    elseif match.has_files(s) then
      local paths = model.section_paths(s)
      if #paths == 0 then
        h.warn(("%s: none of its files were found"):format(s.title), {
          "relative `files` resolve against " .. vim.fn.stdpath "config",
          "`runtime_files` are looked up on 'runtimepath'",
        })
      else
        for _, p in ipairs(paths) do
          h.ok(("%s: %s"):format(s.title, vim.fn.fnamemodify(p, ":~")))
        end
      end
    end
  end

  M.detection(cfg)
end

--- Counts how many maps each origin layer explained, and lists the rest.
--- @param cfg KeymapHelperConfig
function M.detection(cfg)
  local h = vim.health
  h.start "keymap-helper: detection"
  local collect = require "keymap-helper.collect"
  local model = require "keymap-helper.model"
  local track = require "keymap-helper.track"

  if track.installed() then
    local n = vim.tbl_count(track.registry())
    h.ok(("track() active: %d maps recorded"):format(n))
  else
    h.info("track() not active (optional)", {
      "Records the exact file of every vim.keymap.set. Put this at the top of init.lua:",
      'vim.opt.rtp:prepend(vim.fn.stdpath "data" .. "/lazy/keymap-helper.nvim")',
      'require("keymap-helper").track()',
    })
  end

  local ok, data = pcall(model.gather, cfg)
  if not ok then
    h.error("could not gather keymaps: " .. tostring(data))
    return
  end
  local state = model.build(cfg, data, collect.normalize, collect.display)

  local stats = data.stats or { files = 0, capped = false }
  if cfg.detect.scan_config then
    h.ok(("scanned %d config files"):format(stats.files))
    if stats.capped then
      h.warn(("stopped at detect.max_files (%d)"):format(cfg.detect.max_files), {
        "raise detect.max_files if maps from later files are misplaced",
      })
    end
  else
    h.info "config scan disabled (detect.scan_config = false)"
  end
  h.info("lazy.nvim " .. (package.loaded["lazy.core.config"] and "loaded" or "not loaded"))
  h.info("which-key " .. (package.loaded["which-key"] and "loaded" or "not loaded"))

  local via, unknown = {}, {}
  for _, m in ipairs(data.live) do
    local o = m.origin
    if o and o.via ~= "none" then
      via[o.via] = (via[o.via] or 0) + 1
    else
      table.insert(unknown, m)
    end
  end
  local total = #data.live
  local known = total - #unknown
  local parts = {}
  for _, k in ipairs { "track", "lazy_keys", "callback", "sid", "index", "heuristic" } do
    table.insert(parts, ("%s %d"):format(k, via[k] or 0))
  end
  h.ok(("attributed %d of %d maps: %s"):format(known, total, table.concat(parts, " · ")))
  if #unknown > 0 then
    local lines = {}
    for i = 1, math.min(#unknown, 10) do
      local m = unknown[i]
      table.insert(lines, ("%s %s  %s"):format(m.mode, collect.display(m.lhs), m.desc or ""))
    end
    h.warn(
      ("%d maps have no known origin"):format(#unknown),
      vim.list_extend({ "Use track() (see above) or a `runtime_files` section. First ones:" }, lines)
    )
  end

  for _, s in ipairs(state.sections) do
    h.ok(("%s: %d rows"):format(s.title, s.count))
  end
end

return M
