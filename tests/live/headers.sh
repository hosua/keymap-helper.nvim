#!/usr/bin/env bash
# Category headers in the terminal UI and in :KeymapHelper edit, on a COPY of the
# real lua/mappings.lua (15 boxed categories). Private tmux, throwaway XDG dirs.
set -u
P=$(cd "$(dirname "$0")/../.." && pwd)
source "$P/tests/smoke/lib.sh"
tmp=$(mktemp -d)
cfg="$tmp/cfg"
mkdir -p "$cfg/lua"
cp "$HOME/dev/hosua/nvim/lua/mappings.lua" "$cfg/lua/mappings.lua"
env_xdg=(env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x")
trap 'smoke_stop; smoke_rmdir "$tmp"' EXIT
fail=0
chk() { "$@" || fail=1; }
# y keeps the headers as categories (d drops them, everything Uncategorized).
smoke_start 140 40 "${env_xdg[@]}" bun "$P/tui/src/index.tsx" --root "$cfg"
sleep 2
chk smoke_expect 'There is no keymap template yet'
smoke_keys y
sleep 1
chk smoke_expect 'Retired NvChad defaults'
chk smoke_expect '■ Splits +2'
smoke_keys j; smoke_keys j; smoke_keys j; smoke_keys l; smoke_keys Space; smoke_keys m
smoke_type 'Moved here'; smoke_keys Enter; sleep 1
smoke_type w; sleep 1; smoke_keys Enter; sleep 1; smoke_type y; sleep 1; [ "$(grep -c '^-- \[' "$cfg/lua/mappings.lua")" = 16 ] || { echo "  FAIL  want 16 one-line headers"; fail=1; }
[ "$(grep -c '[┌│└]' "$cfg/lua/mappings.lua")" = 0 ] || { echo "  FAIL  box characters in output"; fail=1; }
chk smoke_reject 'E[0-9]+:'
exit $fail
