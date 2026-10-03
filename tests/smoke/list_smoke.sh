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
smoke_expect 'How to read this list'
smoke_expect '<leader> +<Space>'
smoke_expect 'n normal · i insert'
smoke_expect 'Custom  ·  fixture'
smoke_expect '  General'
smoke_expect 'n,x +<leader>gb +git blame line'
# ";" is claimed by the fixture section, so it must not repeat under Default.
# The intro makes the list taller than the window: count it before scrolling
# (Custom's copy) and after (where a Default copy would sit); total must be 1.
[ "$(smoke_screen | grep -c 'CMD enter command mode')" = 1 ] && echo "  ok    ; listed in Custom" || { echo "  FAIL  ; not listed once in Custom"; exit 1; }
smoke_keys C-d
smoke_expect '  Default'
smoke_expect '<leader>zz +unclaimed smoke map'
[ "$(smoke_screen | grep -c 'CMD enter command mode')" = 0 ] && echo "  ok    ; not repeated under Default" || { echo "  FAIL  ; listed twice"; exit 1; }
smoke_reject 'E[0-9]+:'

smoke_keys q
smoke_reject 'Custom  ·  fixture'

smoke_resize 80 24
smoke_keys ':KeymapHelper' Enter
smoke_expect 'Custom  ·  fixture'
smoke_reject 'E[0-9]+:'
smoke_stop
rm -rf "$tmp"
echo "list smoke: ok"
