#!/usr/bin/env bash
# The startup hint and the keymap list float, in a real TUI.
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/smoke/lib.sh
tmp=$(mktemp -d)
env_xdg=(env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x")

smoke_start 120 40 "${env_xdg[@]}" nvim --clean -u tests/smoke/init.lua
smoke_expect 'Type <Space>km to view a list of all keymappings!'
smoke_reject 'E[0-9]+:'

smoke_keys ' ' 'k' 'm'
smoke_expect 'Keymaps'
smoke_expect '▾ How to read this list'
smoke_expect '<leader> +<Space>'
smoke_expect 'n normal · i insert'
smoke_expect '▾ Custom \([0-9]+\)  ·  fixture'
smoke_expect '  General'
smoke_expect 'n,x +<leader>gb +git blame line'
smoke_expect '▸ Default \([0-9]+\)'
smoke_reject '<leader>zz'

# The cursor starts on the intro header: <CR> folds it.
smoke_keys Enter
smoke_expect '▸ How to read this list'
smoke_reject 'n normal · i insert'

# Expand Default: move to its header, <CR>.
smoke_keys ':call search("Default")' Enter
smoke_keys Enter
smoke_expect '▾ Default'
# Default is longer than the window: jump to the row before checking it.
smoke_keys ':call search("unclaimed smoke")' Enter
smoke_expect '<leader>zz +unclaimed smoke map'
smoke_keys gg

# ";" is claimed by the fixture section, so the whole buffer has it once.
smoke_keys ':echo "dups=" . len(filter(getline(1, "$"), "v:val =~# \"CMD enter command mode\""))' Enter
smoke_expect 'dups=1'

# zM closes everything (intro included), zR opens everything.
smoke_keys zM
smoke_expect '▸ How to read this list'
smoke_expect '▸ Custom'
smoke_expect '▸ Default'
smoke_reject 'git blame line'
smoke_keys zR
smoke_expect '▾ How to read this list'
smoke_expect 'git blame line'
smoke_reject 'E[0-9]+:'

smoke_keys q
smoke_reject 'Custom \('

smoke_resize 80 24
smoke_keys ':KeymapHelper' Enter
smoke_expect '▾ Custom'
smoke_reject 'E[0-9]+:'
smoke_stop
rm -rf "$tmp"
echo "list smoke: ok"
