#!/usr/bin/env bash
# Zero-config setup: the one default section is filled from live maps, no
# `files` anywhere, and the default <leader>km opens it. Plain `nvim` against a
# throwaway XDG tree.
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
vim.keymap.set("n", "<leader>aa", "<cmd>echo 'a'<cr>", { desc = "auto one" })
vim.keymap.set("n", "<leader>ab", "<cmd>echo 'b'<cr>", { desc = "auto two" })
require("keymap-helper").setup {}
LUA

smoke_start 120 40 env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x" nvim
smoke_keys ' ' 'k' 'm'
smoke_expect '▾ Default \([0-9]+\)  ·  everything else with a description'
smoke_expect 'auto one'
smoke_reject 'Your config'
smoke_reject 'E[0-9]+:'
smoke_stop
smoke_rmdir "$tmp"
echo "auto smoke: ok"
