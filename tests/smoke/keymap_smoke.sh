#!/usr/bin/env bash
# `keymap = false` maps nothing: <leader>km does not open the list, and the
# startup hint falls back to the command name.
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$(pwd)
source tests/smoke/lib.sh
tmp=$(mktemp -d)
mkdir -p "$tmp/c/nvim"
cat > "$tmp/c/nvim/init.lua" <<LUA
vim.opt.runtimepath:prepend("$root")
vim.g.mapleader = " "
vim.cmd "runtime plugin/keymap-helper.lua"
require("keymap-helper").setup { keymap = false }
LUA

smoke_start 120 40 env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x" nvim
smoke_expect 'Type :KeymapHelper to view'
smoke_keys ' ' 'k' 'm'
smoke_reject '▾ Default'
smoke_reject 'E[0-9]+:'
smoke_stop
smoke_rmdir "$tmp"
echo "keymap smoke: ok"
