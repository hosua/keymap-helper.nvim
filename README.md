# keymap-helper.nvim

Grouped, collapsible keymap reference for any Neovim config

## Install

Requires Neovim >= 0.11. With lazy.nvim:

```lua
{ "hosua/keymap-helper.nvim", cmd = { "KeymapHelper" }, opts = {} }
```

## Commands

| Command | What it does |
|---|---|

## Default keymaps

None are installed unless `keymaps = true`. Suggested:

| Key | Command |
|---|---|

## Configuration

Every option, with its default:

```lua
require("keymap-helper").setup {
  notify = true,
}
```

## Health

`:checkhealth keymap-helper`

## Development

```bash
make test         # headless unit tests, no dependencies
make integration  # against a throwaway XDG tree
make check        # stylua --check
```
