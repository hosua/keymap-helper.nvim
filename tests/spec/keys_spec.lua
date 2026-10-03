local keys = require "keymap-helper.ui.keys"

describe("list keys", function()
  it("builds the footer from the bound keys", function()
    eq("<CR> toggle section · zR open all · zM close all · q close", keys.footer())
  end)

  it("follows the table: change a key and the footer changes", function()
    local saved = keys.ACTIONS.quit.keys
    keys.ACTIONS.quit.keys = { "x" }
    local footer = keys.footer()
    keys.ACTIONS.quit.keys = saved
    ok(footer:find("x close", 1, true), footer)
  end)

  it("binds every footer key in the real list buffer", function()
    local model = require "keymap-helper.model"
    local state = { sections = {}, footer = keys.footer() }
    local _, buf =
      require("keymap-helper.ui.float").open_list(state, model.initial_view(state), { title = "t", max_width = 40 })
    local bound = {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      bound[vim.fn.keytrans(m.lhsraw or vim.keycode(m.lhs))] = true
    end
    vim.cmd "bwipeout!"
    for _, name in ipairs { "toggle", "open_all", "close_all", "quit" } do
      ok(bound[keys.ACTIONS[name].keys[1]], keys.ACTIONS[name].keys[1] .. " not bound")
    end
  end)
end)
