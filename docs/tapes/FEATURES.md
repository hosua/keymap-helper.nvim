# Feature coverage for README media

Every user-facing feature of keymap-helper.nvim and the README media that shows it.
Regenerate media: `bash docs/tapes/capture.sh [slug...]`. Check coverage:
`coverage-report.sh docs/tapes/FEATURES.md` (from the gh-readme-screengrab-helper skill).

Status: `covered` (seen in the frame named in Evidence) | `excluded` (reason in Evidence) |
`unverified` (captured, not checked) | `missing` (no shot) | `stale` (changed since capture).

Last full inventory: 2026-10-03 at commit `86d92cb`.

| ID | Feature | Kind | Trigger | Source | Shot | Evidence | Status |
|---|---|---|---|---|---|---|---|
| F01 | List opens with the default <leader>km (installed by plugin/, no config) | keymap | `<Space>km` | plugin/keymap-helper.lua:22, lua/keymap-helper/keymap.lua | default.png | whole image: float titled "Keymaps" opened by typing Space k m, no setup keymap in demo/default/init.lua | covered |
| F02 | :KeymapHelper / :KeymapHelper show opens the list | command | `:KeymapHelper` | lua/keymap-helper/commands.lua:8 | commands.gif | f295: "Keymaps" float open after bare `:KeymapHelper` | covered |
| F03 | :KeymapHelper hint shows the hint again | command | `:KeymapHelper hint` | lua/keymap-helper/commands.lua:11 | commands.gif | f100: toast "Type <Space>km to view a list of all keymappings!" with `:KeymapHelper hint` in the cmdline | covered |
| F04 | :KeymapHelper health = :checkhealth keymap-helper | command | `:KeymapHelper health` | lua/keymap-helper/commands.lua:14, health.lua | health.png | whole image: health:// buffer with sections, detection and "Custom: 15 rows" lines | covered |
| F05 | Unknown subcommand error | state | `:KeymapHelper bogus` | lua/keymap-helper/commands.lua:26 | commands.gif | f187: red message `unknown subcommand "bogus" (have: health, hint, show)` | covered |
| F06 | Centered startup hint | view | start nvim | lua/keymap-helper/init.lua:57, ui/float.lua:150 | hint.png | whole image: centered bordered box "Type <Space>km to view a list of all keymappings!" | covered |
| F07 | "How to read this list" legend, expanded (leader keys, mode letters, key notation) | view | open list | lua/keymap-helper/intro.lua | intro.png | whole image: `<leader> <Space>`, `<localleader> \ (default)`, Modes and Keys lines | covered |
| F08 | <CR> folds the intro (cursor starts on it) | keymap | `<CR>` on the intro header | lua/keymap-helper/ui/float.lua:97 | fold-keys.gif | f75: intro shown as "▸ How to read this list" after `<CR>` (f0 had it open) | covered |
| F09 | Zero-config: one expanded "Default" section | view | `setup {}` | lua/keymap-helper/config.lua:30 | default.png | whole image: "▾ Default (69)  ·  everything else with a description" with the demo maps first | covered |
| F10 | Section grouped by -- │ Name │ header comments | config | `group_by = "header"` | lua/keymap-helper/group.lua, config.lua:22 | custom.png | whole image: groups General, Splits, Git / goto  (<leader>g), Telescope  (<leader>f) | covered |
| F11 | runtime_files section, folded; a map the user file overrides shows once | config | `runtime_files = {...}, collapsed = true` | lua/keymap-helper/model.lua, config.lua:18 | custom.png | whole image: "▸ NvChad defaults (21)" (22 in one-section.png, where `<C-s>` is not overridden) | covered |
| F12 | Implicit folded "Default" section at the end | view | no `rest` section configured | lua/keymap-helper/model.lua | custom.png | whole image: "▸ Default (64)  ·  everything else with a description" after NvChad defaults | covered |
| F13 | One-line config: one section plus implicit Default | config | `sections = { { title = "NvChad defaults", runtime_files = {...}, collapsed = true } }` | README.md "Only want NvChad's maps split out?" | one-section.png | whole image: "▸ NvChad defaults (22)" then "▸ Default (66)" | covered |
| F14 | <CR> toggles the section under the cursor | keymap | `<CR>` on "NvChad defaults" | lua/keymap-helper/ui/float.lua:97 | nvchad-submenu.gif | f90 folded with cursor on NvChad, f137 expanded: 21 rows from "move beginning of line" | covered |
| F15 | l open, h close, za and <Tab> toggle | keymap | `h`, `l`, `za`, `<Tab>` on "Custom" | lua/keymap-helper/ui/float.lua:97-99 | fold-keys.gif | f112 Custom closed (h), f150 open (l), f187 closed (za), f237 open (Tab) | covered |
| F16 | zM closes all sections, zR opens all (intro too) | keymap | `zM`, `zR` | lua/keymap-helper/ui/float.lua:101-107 | nvchad-submenu.gif | f195 every header incl. the intro folded (zM), f250 intro, Custom and NvChad open (zR) | covered |
| F17 | q / <Esc> close the list | keymap | `q`, `<Esc>` | lua/keymap-helper/ui/float.lua:131 | commands.gif fold-keys.gif | commands f390: list gone after `q`; fold-keys f310: list gone after Esc | covered |
| F18 | Left click on a section header toggles it | keymap | click header | lua/keymap-helper/ui/float.lua:112 | - | duplicate:F14 (same fold result; vhs/ttyd cannot send mouse events) | excluded |
| F19 | group_by = "leader_prefix" | config | `group_by = "leader_prefix"` | lua/keymap-helper/group.lua:46 | group-by.png | whole image: groups `<leader>` and `<leader>f` under "Everything else" | covered |
| F20 | group_by = "plugin" | config | `plugin = true, group_by = "plugin"` | lua/keymap-helper/group.lua | group-by.png | whole image: groups gitsigns.nvim and telescope.nvim under "Plugins (5)" | covered |
| F21 | Matcher lhs pattern | config | `lhs = "^<leader>g"` | lua/keymap-helper/match.lua | group-by.png | whole image: "Git (3)  ·  lhs = ^<leader>g" with the three `<leader>g*` rows | covered |
| F22 | Other matchers: config, builtin, mode, desc, fn, files, hidden | config | section keys | lua/keymap-helper/match.lua | - | no-visual: they only change which rows a section claims (`files` is shown in custom.png, `config` in group-by.png); README "Recipes" has the snippets | excluded |
| F23 | show_undocumented = true lists maps without desc | config | `show_undocumented = true` | lua/keymap-helper/config.lua:36 | undocumented.png | whole image: `jk`, `<leader>bd` and `<Plug>(demo-action)` rows with blank descriptions | covered |
| F24 | keymap option (other key, or false) | config | `keymap = "<leader>?"` | lua/keymap-helper/keymap.lua | - | no-visual: only changes which key opens the same list (the hint shows it, see F26); README "Install" has the snippet | excluded |
| F25 | window.title, window.max_width, window.footer | config | `window = {...}` | lua/keymap-helper/config.lua:67 | - | no-visual: cosmetic string/width values, README "Configuration" lists them | excluded |
| F26 | hint.position = "bottom_right", hint.message, hint.timeout_ms | config | `hint = { position = "bottom_right", message = "Press {key} for your keymaps" }` | lua/keymap-helper/init.lua:57, config.lua:73 | hint-corner.png | whole image: box "Press <Space>km for your keymaps" in the bottom-right corner | covered |
| F27 | intro.enabled / intro.collapsed | config | `intro = {...}` | lua/keymap-helper/config.lua:81 | - | duplicate:F07 (intro folded/removed looks like the folded intro in F08) | excluded |
| F28 | track() and its health line | integration | `require("keymap-helper").track()` | lua/keymap-helper/init.lua:35, track.lua | health.png | whole image: "OK track() active: 42 maps recorded" | covered |
| F29 | modes, header_pattern, map_functions, detect.* | config | `setup { ... }` | lua/keymap-helper/config.lua:48-65 | - | no-visual: change detection inputs only (health.png shows "scanned 2 config files"); README "Configuration" has the defaults | excluded |
| F30 | Row colours: mode, key (Special) and description (Comment) differ | view | any open list | lua/keymap-helper/highlights.lua | custom.png | whole image: modes red, keys teal, descriptions grey, group titles bold white | covered |
| F31 | lazy.nvim keys and which-key group names in the list | integration | `detect.lazy_keys`, `detect.which_key` | lua/keymap-helper/index.lua, whichkey.lua | - | account: needs lazy.nvim / which-key.nvim installed (network); health.png shows "lazy.nvim not loaded" and "which-key not loaded" | excluded |

## Shots

| Shot | Kind | Rows | Size | Duration |
|---|---|---|---|---|
| default.png | png | F01 F09 | 175 KB | - |
| custom.png | png | F10 F11 F12 F30 | 145 KB | - |
| one-section.png | png | F13 | 67 KB | - |
| intro.png | png | F07 | 170 KB | - |
| hint.png | png | F06 | 45 KB | - |
| hint-corner.png | png | F26 | 43 KB | - |
| group-by.png | png | F19 F20 F21 | 110 KB | - |
| undocumented.png | png | F23 | 79 KB | - |
| health.png | png | F04 F28 | 158 KB | - |
| nvchad-submenu.gif | gif | F14 F16 | 331 KB | 11.8 s |
| fold-keys.gif | gif | F08 F15 F17 | 383 KB | 12.5 s |
| commands.gif | gif | F02 F03 F05 F17 | 167 KB | 15.8 s |
