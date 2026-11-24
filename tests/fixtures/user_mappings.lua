require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Retired NvChad defaults                                                   │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Rehomed into the prefixed namespaces below. pcall so a future NvChad release
-- that drops one of these does not break the rest of this file.
for _, lhs in ipairs {
  "<leader>v", -- vertical terminal -> <leader>Tv
  "<leader>n", -- toggle line number -> <leader>ln
  "<leader>rn", -- toggle relative number -> <leader>lr
  "<leader>cm", -- telescope git commits -> <leader>fg
  "<leader>ds", -- LSP diagnostic loclist -> (unmapped; <leader>d is devdocs)
} do
  pcall(vim.keymap.del, "n", lhs)
end

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ General                                                                   │
-- └───────────────────────────────────────────────────────────────────────────┘

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- NvChad puts <leader>h on a horizontal terminal, which now lives at
-- <leader>Th, so <leader>h is free for the help_tags picker. Its <leader>ch
-- cheatsheet is untouched -- <leader>? is just a second, shorter way in.
-- ? is the quick reference; h is the exhaustive one. <leader>fh is NvChad's
-- own binding for the same help_tags picker and still works.
map("n", "<leader>?", "<cmd>NvCheatsheet<CR>", { desc = "toggle nvcheatsheet" })
map("n", "<leader>h", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })

-- Search popup for Brave. In visual mode the selection is prefilled.
map({ "n", "x" }, "<leader>q", function()
  require("configs.browser").open()
end, { desc = "Search brave (selection or typed query)" })

map("n", "<leader>sp", function()
  vim.notify(vim.fn.expand "%:p", vim.log.levels.INFO, { title = "File path" })
end, { desc = "Show full file path" })

-- Wrap the word under the cursor, or the selection. ~ is the triple-backtick
-- one; on a linewise selection it makes a fenced block.
for lhs, text in pairs { ["'"] = "'", ['"'] = '"', ["`"] = "`", ["~"] = "```" } do
  map({ "n", "x" }, "<leader>" .. lhs, function()
    require("configs.wrap").wrap(text)
  end, { desc = "wrap word or selection in " .. text })
end

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Splits                                                                    │
-- └───────────────────────────────────────────────────────────────────────────┘

map("n", "<leader>-", "<cmd>vsp<CR>", { desc = "split vertically" })
map("n", "<leader>=", "<cmd>sp<CR>", { desc = "split horizontally" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ LSP / diagnostics                                                         │
-- └───────────────────────────────────────────────────────────────────────────┘

map("n", "<leader>se", vim.diagnostic.open_float, { desc = "Show diagnostics under cursor" })

-- Every diagnostic in this buffer; the uppercase counterpart to <leader>se,
-- which shows only the one under the cursor. Telescope rather than
-- vim.diagnostic.setloclist so the list is fuzzy-filterable and previewed;
-- bufnr = 0 scopes it to the current file instead of the whole workspace.
map("n", "<leader>sE", function()
  require("telescope.builtin").diagnostics { bufnr = 0 }
end, { desc = "Show all diagnostics in current file" })
map("n", "<leader>sf", vim.lsp.buf.code_action, { desc = "Show/apply code fixes" })
map("n", "<leader>sd", vim.lsp.buf.hover, { desc = "Show function documentation" })

-- gx opens docs for diagnostics and other text the rules in configs/gx.lua
-- know (SC2145 -> shellcheck wiki). Anything else falls through to Neovim's
-- own gx, captured here.
local default_gx = vim.fn.maparg("gx", "n", false, true).callback
  or function()
    for _, url in ipairs(require("vim.ui")._get_urls()) do
      vim.ui.open(url)
    end
  end
map(
  "n",
  "gx",
  require("configs.gx").gx(default_gx),
  { desc = "Open docs for diagnostic/rule match, else URI under cursor" }
)

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Reset  (<leader>r)                                                        │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Destructive, so it asks first: reset_buffer throws away every unstaged
-- change in the buffer and git has no copy to restore from.
map("n", "<leader>rB", function()
  local danger = require "configs.danger"
  danger.guard(":Gitsigns reset_buffer", danger.gitsigns.reset_buffer, function()
    vim.cmd "Gitsigns reset_buffer"
  end)
end, { desc = "reset buffer (DANGER: discards changes)" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Line display  (<leader>l)                                                 │
-- └───────────────────────────────────────────────────────────────────────────┘

map("n", "<leader>ln", "<cmd>set nu!<CR>", { desc = "toggle line number" })
map("n", "<leader>lr", "<cmd>set rnu!<CR>", { desc = "toggle relative line number" })
map("n", "<leader>lw", "<cmd>set wrap!<CR>", { desc = "toggle line wrap" })
map("n", "<leader>lc", "<cmd>set cursorline!<CR>", { desc = "toggle cursorline" })
map("n", "<leader>ll", "<cmd>set list!<CR>", { desc = "toggle invisible characters" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Git / goto  (<leader>g)                                                   │
-- └───────────────────────────────────────────────────────────────────────────┘

map("n", "<leader>gg", "<cmd>LazyGit<CR>", { desc = "open lazygit TUI" })
map("n", "<leader>gb", "<cmd>Gitsigns blame<CR>", { desc = "blame current line" })
-- In that blame panel, gx opens the commit on the line in the browser
-- (the host's commit page) instead of looking for a URL under the cursor.
-- Implementation in lua/configs/git_link.lua.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitsigns-blame",
  callback = function(ev)
    map("n", "gx", function()
      require("configs.git_link").open_commit()
    end, { buffer = ev.buf, desc = "open blamed commit in browser" })
  end,
})
map("n", "<leader>gl", "<cmd>Gitsigns blame_line<CR>", { desc = "blame cursor line (float)" })
-- Trying diffview.nvim in place of the smart gd below (gD's menu uses it too). It opens a tab with
-- the changed files on the left and a side-by-side diff on the right. With no
-- arguments it shows uncommitted work (staged and unstaged) against HEAD.
-- Pressing gd again, or q inside it, closes the tab. gx in its file list
-- opens the same diff in the browser. <leader>gD picks other ranges, and
-- :DiffviewFileHistory % lists this file's commits.
-- Plugin spec in lua/plugins/init.lua.
map("n", "<leader>gd", function()
  if require("diffview.lib").get_current_view() then
    vim.cmd "DiffviewClose"
  else
    vim.cmd "DiffviewOpen"
  end
end, { desc = "toggle diffview (uncommitted vs HEAD)" })

-- Disabled while trying diffview (above). Uncomment this and remove the
-- diffview gd to go back.
-- Smart: dirty tree -> working tree diff; clean tree -> menu of best guesses
-- (branch vs trunk, last commit) plus recent commits. In the menu: Enter on a
-- smart row runs it (A); Space on two commits diffs oldest..newest (B); Space
-- on one commit then Enter compares it with the working tree, HEAD, the trunk
-- or a branch (C); typing a..b / a...b / a ref diffs that. Any count
-- (1<leader>gd) forces the menu. A popup lists merge conflicts with the trunk
-- first, if there are any.
-- Implementation in lua/configs/git_smart.lua.
-- map("n", "<leader>gd", function()
--   require("configs.git_smart").diff_smart { force_menu = vim.v.count > 0 }
-- end, { desc = "smart git diff (count = menu)" })

-- Yank the web URL of the commit under the cursor: the blame panel line,
-- a hash under the cursor, or else the commit that last touched this line.
-- Works for any git host. Implementation in lua/configs/git_link.lua.
map("n", "<leader>gL", function()
  require("configs.git_link").yank_commit_url()
end, { desc = "yank web link to commit under cursor" })

-- Open this repo's web page (origin remote, as https) in the default browser.
-- Works from any file nested in a repo. Implementation in lua/configs/git_link.lua.
map("n", "<leader>go", function()
  require("configs.git_link").open_repo()
end, { desc = "open git repo in browser" })

-- Fetches, then opens a menu of diffs, shown in diffview: the branch +
-- uncommitted work vs the trunk, the branch's commits vs the trunk, HEAD vs
-- another branch, or a commit. Space on two commits diffs them
-- oldest..newest; Space on one commit compares it with the working tree,
-- HEAD, origin/<branch>, the trunk or another branch. Typing a..b diffs
-- that. Implementation in lua/configs/git.lua (fetch), git_trunk.lua and
-- git_smart.lua (the menu).
map("n", "<leader>gD", function()
  require("configs.git").diff_vs_base { force_menu = true }
end, { desc = "pick a diff (branch, commits, a..b) in diffview" })

-- The smart gD from before diffview, disabled. It fetched, then showed
-- everything the branch changed since it left the trunk (origin/HEAD),
-- uncommitted work included: with a dirty tree that is the merge base
-- against the working tree, otherwise base...HEAD. A count (1<leader>gD)
-- opened the menu instead.
-- map("n", "<leader>gD", function()
--   require("configs.git").diff_vs_base { force_menu = vim.v.count > 0 }
-- end, { desc = "diff branch + uncommitted vs trunk (count = menu)" })

-- What the old gD showed on its own, as plain unified text, for grepping,
-- yanking or piping. Implementation in lua/configs/git_trunk.lua.
map("n", "<leader>gp", function()
  require("configs.git").diff_vs_base { raw = true }
end, { desc = "diff branch against origin main/master (plain text)" })

-- Staging is reversible, so it fires directly. The reset counterpart is
-- destructive and lives under <leader>r instead; see the Reset section.
map("n", "<leader>gS", "<cmd>Gitsigns stage_buffer<CR>", { desc = "stage whole buffer" })

-- Not git: <leader>g doubles as the "goto" prefix. Telescope's picker rather
-- than vim.lsp.buf.references, which dumps straight to the quickfix list with
-- no fuzzy filtering -- same choice LazyVim makes. Neovim 0.11+ also ships a
-- built-in grr for this, outside the <leader> namespace.
map("n", "<leader>gr", function()
  require("telescope.builtin").lsp_references()
end, { desc = "goto references (LSP)" })

-- Browser preview of the current markdown buffer (markdown-preview.nvim).
-- Implementation in lua/configs/markdown_preview.lua.
map("n", "<leader>gm", function()
  require("configs.markdown_preview").open()
end, { desc = "markdown preview in browser" })

-- Menu of every :Gitsigns command, with a description and a preview of what
-- the command would act on right now. Implementation in lua/configs/pickers.lua.
map("n", "<leader>g?", function()
  require("configs.pickers").gitsigns()
end, { desc = "pick a gitsigns command" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Toggles & Terminal <leader>t                                              │
-- └───────────────────────────────────────────────────────────────────────────┘

local format_on_save_enabled = true -- Track state ourselves

map("n", "<leader>tf", function()
  local conform = require "conform"
  format_on_save_enabled = not format_on_save_enabled

  if format_on_save_enabled then
    conform.setup { format_on_save = require("configs.conform").format_on_save }
    vim.notify("Format on save: ENABLED", vim.log.levels.INFO)
  else
    conform.setup { format_on_save = false }
    vim.notify("Format on save: DISABLED", vim.log.levels.INFO)
  end
end, { desc = "Toggle format on save" })

map({ "n", "i" }, "<leader>to", function()
  require("base46").toggle_transparency()
end, { desc = "toggle opacity" })

map("n", "<leader>tt", function()
  require("nvchad.term").new { pos = "sp" }
end, { desc = "open horizontal terminal buffer" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Pickers(<leader>pt)                                                     │
-- └───────────────────────────────────────────────────────────────────────────┘

map("n", "<leader>pf", function()
  require("configs.formatter_picker").pick()
end, { desc = "pick formatter for this file" })

map("n", "<leader>fp", function()
  require("configs.formatter_picker").pick()
end, { desc = "pick formatter for this file, name, extension or filetype" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ UI / messages                                                             │
-- └───────────────────────────────────────────────────────────────────────────┘

map({ "n", "i" }, "<leader>sm", function()
  local MAX_MESSAGES = 50

  local msgs = vim.fn.execute "messages"
  local lines = vim.split(msgs, "\n")

  local reversed_lines = {}
  for i = #lines, math.max(#lines - MAX_MESSAGES + 1, 1), -1 do
    table.insert(reversed_lines, lines[i])
  end

  vim.cmd "botright new"
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, reversed_lines)

  local bo = vim.bo
  bo.buftype = "nofile"
  bo.bufhidden = "wipe"
  bo.swapfile = false
  bo.modifiable = false

  vim.api.nvim_win_set_height(0, 15)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end, { desc = "Show messages in bottom pane" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Telescope  (<leader>f)                                                    │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Telescope documents every builtin with a `---` block directly above its
-- assignment in telescope/builtin/init.lua. Parse that instead of keeping a
-- hand-written description table in sync: new builtins get docs for free.
local telescope_docs_cache

local function telescope_docs()
  if telescope_docs_cache then
    return telescope_docs_cache
  end

  local docs = {}
  local file = vim.api.nvim_get_runtime_file("lua/telescope/builtin/init.lua", false)[1]

  if file then
    local pending = {}
    for line in io.lines(file) do
      local comment = line:match "^%-%-%-(.*)$"
      local name = line:match "^builtin%.([%w_]+)%s*="
      if comment then
        table.insert(pending, (comment:gsub("^ ", "")))
      elseif name then
        docs[name] = pending
        pending = {}
      else
        pending = {}
      end
    end
  end

  telescope_docs_cache = docs
  return docs
end

-- Description on top, the @param/@field detail underneath.
local function telescope_doc_lines(name)
  local raw = telescope_docs()[name]
  local lines = { "# :Telescope " .. name, "" }

  if not raw or #raw == 0 then
    table.insert(lines, "_Undocumented in telescope's source._")
    return lines
  end

  local description, detail = {}, {}
  for _, line in ipairs(raw) do
    table.insert(line:match "^@" and detail or description, line)
  end

  vim.list_extend(lines, description)

  if #detail > 0 then
    vim.list_extend(lines, { "", "## Options", "" })
    for _, line in ipairs(detail) do
      table.insert(lines, "- " .. line)
    end
  end

  return lines
end

-- Builds a picker whose entries are other pickers: fuzzy-find a :Telescope
-- command, read what it does in the preview, hit <CR> to run it.
local function telescope_menu(title, pattern)
  return function()
    local builtin = require "telescope.builtin"
    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local previewers = require "telescope.previewers"
    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"
    local conf = require("telescope.config").values

    local names = {}
    for name in pairs(builtin) do
      if not pattern or name:match(pattern) then
        table.insert(names, name)
      end
    end
    table.sort(names)

    pickers
      .new({}, {
        prompt_title = title,
        finder = finders.new_table {
          results = names,
          entry_maker = function(name)
            return { value = name, display = ":Telescope " .. name, ordinal = name }
          end,
        },
        sorter = conf.generic_sorter {},
        previewer = previewers.new_buffer_previewer {
          title = "Description",
          define_preview = function(self, entry)
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, telescope_doc_lines(entry.value))
            vim.bo[self.state.bufnr].filetype = "markdown"
            if self.state.winid then
              vim.wo[self.state.winid].wrap = true
            end
          end,
        },
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not selection then
              return
            end
            -- Schedule so the menu is torn down before the next picker opens.
            vim.schedule(function()
              local ok, err = pcall(builtin[selection.value])
              if not ok then
                vim.notify(
                  (":Telescope %s failed: %s"):format(selection.value, err),
                  vim.log.levels.ERROR,
                  { title = "Telescope" }
                )
              end
            end)
          end)
          return true
        end,
      })
      :find()
  end
end

map("n", "<leader>f?", telescope_menu("All telescope pickers", nil), { desc = "telescope pick any picker" })
map("n", "<leader>fg", telescope_menu("Telescope git pickers", "^git_"), { desc = "telescope pick a git picker" })
map("n", "<leader>fl", telescope_menu("Telescope LSP pickers", "^lsp_"), { desc = "telescope pick an lsp picker" })

map("n", "<leader>fc", "<cmd>Telescope git_commits<CR>", { desc = "telescope git commits" })

-- <leader>km (grouped keymap list) is keymap-helper.nvim's own default map;
-- sections are configured in lua/plugins/keymap-helper.lua.
map("n", "<leader>kM", "<cmd>Telescope keymaps<CR>", { desc = "telescope keymaps" })
map("n", "<leader>k?", "<cmd>Telescope keymaps<CR>", { desc = "telescope keymaps" })

-- Grep only inside .github (workflows, actions, templates)
map("n", "<leader>fG", function()
  require("telescope.builtin").live_grep {
    search_dirs = { ".github" },
    prompt_title = "Live Grep (.github)",
    additional_args = { "--hidden" },
  }
end, { desc = "telescope live grep in .github" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Sessions                                                                  │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Named, per-project sessions: session-mgr.nvim (~/dev/session-mgr.nvim, spec
-- in lua/plugins/session-mgr.lua). The rhs is a command STRING on purpose:
-- lazy's `cmd = { "SessionMgr" }` stub loads the plugin on first use, and the
-- plugin finds these keys via nvim_get_keymap to say "or <leader>sl" in its
-- messages, which it could not do with a Lua callback.
-- sS and sL skip the prompts. sS saves the project's `default` session. sL
-- loads autosave.vim while autosave is on, else `default`. sA lists every
-- project; sa switches autosave (autosave.vim every 5 minutes, loaded again
-- when nvim starts without files) on or off for this nvim. sn starts empty.
map("n", "<leader>ss", "<cmd>SessionMgr save<cr>", { desc = "session save as (named)" })
map("n", "<leader>sl", "<cmd>SessionMgr load<cr>", { desc = "session load (this project)" })
map("n", "<leader>sa", "<cmd>SessionMgr autosave<cr>", { desc = "session autosave on/off" })
map("n", "<leader>sA", "<cmd>SessionMgr all<cr>", { desc = "session load (all projects)" })
map("n", "<leader>sn", "<cmd>SessionMgr new<cr>", { desc = "session new (start empty)" })
map("n", "<leader>sS", "<cmd>SessionMgr save!<cr>", { desc = "session save default" })
map("n", "<leader>sL", "<cmd>SessionMgr load!<cr>", { desc = "session load autosave or default" })
map("n", "<leader>sP", "<cmd>SessionMgr procs<cr>", { desc = "session processes (nvim memory, kill)" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ CodeCompanion (Claude via ACP)                                            │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Everything lives under <leader>c, for "companion". <leader>cf (formatter
-- picker) and NvChad's <leader>ch (cheatsheet) were already taken there, so
-- they are skipped. No key here is <leader>cc plus a suffix: that would make
-- <leader>cc wait for 'timeoutlen' before toggling.
--
-- Visual-mode maps use ":" rather than <cmd> on purpose: ":" inserts '<,'>
-- so the command sees the selection as its range, which <cmd> does not.
-- The /explain /fix /tests /lsp prompts only exist in visual mode upstream.
-- The commands are the plugin's lazy-load trigger, see lua/plugins/init.lua.
map("n", "<leader>c?", function()
  require("configs.browser").open "https://codecompanion.olimorris.dev/"
end, { desc = "open codecompanion docs in browser" })

map({ "n", "v" }, "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", { desc = "codecompanion chat toggle" })
map("n", "<leader>cn", "<cmd>CodeCompanionChat<cr>", { desc = "codecompanion new chat" })
map("v", "<leader>cn", ":CodeCompanionChat<cr>", { desc = "codecompanion new chat with selection" })
map("n", "<leader>ca", "<cmd>CodeCompanionActions<cr>", { desc = "codecompanion actions palette" })
map("v", "<leader>ca", ":CodeCompanionActions<cr>", { desc = "codecompanion actions palette" })
map("n", "<leader>cd", "<cmd>CodeCompanionChat Add<cr>", { desc = "codecompanion add buffer to chat" })
map("v", "<leader>cd", ":CodeCompanionChat Add<cr>", { desc = "codecompanion add selection to chat" })
map("n", "<leader>ci", "<cmd>CodeCompanion<cr>", { desc = "codecompanion inline assistant" })
map("v", "<leader>ci", ":CodeCompanion<cr>", { desc = "codecompanion inline assistant on selection" })
map("v", "<leader>ce", ":CodeCompanion /explain<cr>", { desc = "codecompanion explain selection" })
map("v", "<leader>cx", ":CodeCompanion /fix<cr>", { desc = "codecompanion fix selection" })
map("v", "<leader>ct", ":CodeCompanion /tests<cr>", { desc = "codecompanion unit tests for selection" })
map("v", "<leader>cl", ":CodeCompanion /lsp<cr>", { desc = "codecompanion explain lsp diagnostics" })
map("n", "<leader>cg", "<cmd>CodeCompanion /commit<cr>", { desc = "codecompanion commit message" })
map("n", "<leader>cr", "<cmd>CodeCompanionCodeReview<cr>", { desc = "codecompanion review agent edits" })
map("n", "<leader>cq", "<cmd>CodeCompanionChat Changes<cr>", { desc = "codecompanion edited files to quickfix" })
map("n", "<leader>cs", function()
  require("codecompanion").sessions()
end, { desc = "codecompanion restore session" })
map("n", "<leader>c:", "<cmd>CodeCompanionCmd<cr>", { desc = "codecompanion write a : command" })
map("n", "<leader>cR", "<cmd>CodeCompanionChat RefreshCache<cr>", { desc = "codecompanion refresh tool cache" })

-- Normal-mode versions of the visual-only prompts. A "." or "%" range counts
-- as a selection upstream, so these act on the cursor line (or, for tests,
-- the whole buffer) without selecting anything first. <leader>cx sits next to
-- the LSP-only <leader>sf code action: AI fix vs. language-server fix.
map("n", "<leader>ce", "<cmd>.CodeCompanion /explain<cr>", { desc = "codecompanion explain current line" })
map("n", "<leader>cx", "<cmd>.CodeCompanion /fix<cr>", { desc = "codecompanion fix current line" })
map("n", "<leader>cl", "<cmd>.CodeCompanion /lsp<cr>", { desc = "codecompanion explain line diagnostics" })
map("n", "<leader>ct", "<cmd>%CodeCompanion /tests<cr>", { desc = "codecompanion unit tests for buffer" })

-- Ask a one-off question: leaves ":CodeCompanionChat " on the command line
-- for you to type the question, then opens a chat with it already sent. In
-- visual mode the selection goes along as context.
map("n", "<leader>ck", ":CodeCompanionChat ", { desc = "codecompanion ask a question" })
map("v", "<leader>ck", ":CodeCompanionChat ", { desc = "codecompanion ask about selection" })
map("n", "<leader>cw", "<cmd>CodeCompanionCodeReview branch<cr>", { desc = "codecompanion review whole branch" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ DevDocs  (<leader>d)                                                      │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Offline devdocs.io docs: devdocs.nvim (~/dev/devdocs.nvim, spec in
-- lua/plugins/devdocs.lua). Command STRINGS for the same reason as the session
-- maps: lazy's `cmd` stub loads the plugin on first use. ds/de also work on a
-- visual selection. Capital I is the direct variant: install a named doc.
map({ "n", "v" }, "<leader>ds", "<cmd>DevDocs definition<cr>", { desc = "devdocs show definition" })
map({ "n", "v" }, "<leader>de", "<cmd>DevDocs example<cr>", { desc = "devdocs show example" })
map("n", "<leader>df", "<cmd>DevDocs search<cr>", { desc = "devdocs search all docs" })
map("n", "<leader>dl", "<cmd>DevDocs list<cr>", { desc = "devdocs list / manage docs" })
map("n", "<leader>do", "<cmd>DevDocs open<cr>", { desc = "devdocs open the index of this buffer's doc" })
map("n", "<leader>di", "<cmd>DevDocs install<cr>", { desc = "devdocs install docs for this buffer" })
map("n", "<leader>dI", ":DevDocs install ", { desc = "devdocs install a named doc" })
map("n", "<leader>da", "<cmd>DevDocs install-all<cr>", { desc = "devdocs install all docs" })
map("n", "<leader>dr", "<cmd>DevDocs resync<cr>", { desc = "devdocs re-detect project languages/versions" })

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Debug (DAP)  (<leader>D)                                                  │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Debugging. Implementation: lua/configs/dap.lua (adapters come from Mason).
-- require("dap") inside each function is what lazy-loads nvim-dap.
-- Moved from <leader>d* to <leader>D* when <leader>d became the devdocs prefix.
map("n", "<leader>Db", function()
  require("dap").toggle_breakpoint()
end, { desc = "debug toggle breakpoint" })
map("n", "<leader>DB", function()
  require("dap").set_breakpoint(vim.fn.input "Breakpoint condition: ")
end, { desc = "debug conditional breakpoint" })
map("n", "<leader>Dc", function()
  require("dap").continue()
end, { desc = "debug start / continue" })
map("n", "<leader>Di", function()
  require("dap").step_into()
end, { desc = "debug step into" })
map("n", "<leader>Do", function()
  require("dap").step_over()
end, { desc = "debug step over" })
map("n", "<leader>DO", function()
  require("dap").step_out()
end, { desc = "debug step out" })
map("n", "<leader>Dx", function()
  require("dap").terminate()
end, { desc = "debug terminate" })
map("n", "<leader>Dv", function()
  require "dap" -- dap-view is a dependency of nvim-dap, load that first
  require("dap-view").toggle()
end, { desc = "debug toggle view" })
