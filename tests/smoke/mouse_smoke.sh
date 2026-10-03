#!/usr/bin/env bash
# Mouse in the list float, sent as real SGR terminal sequences: a click on a
# section header toggles it, and a click in another window leaves the float.
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/smoke/lib.sh
tmp=$(mktemp -d)

click() { # click <col> <row>, 1-based screen cells
  tmux -L "$SMOKE_SOCK" send-keys -l $'\e[<0;'"$1;$2"'M'
  tmux -L "$SMOKE_SOCK" send-keys -l $'\e[<0;'"$1;$2"'m'
  sleep "$SMOKE_WAIT"
}

smoke_start 120 40 env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x" \
  nvim --clean -u tests/smoke/init.lua -c "set mouse=a" -c vsplit
smoke_keys ':KeymapHelper' Enter
smoke_expect '▾ Custom'

row=$(smoke_screen | grep -n '▾ Custom' | cut -d: -f1)
col=$(smoke_screen | sed -n "${row}p" | python3 -c 'import sys; print(sys.stdin.read().index("▾") + 3)')
click "$col" "$row"
smoke_expect '▸ Custom'
smoke_reject 'git blame line'

click 3 3
smoke_keys ':echo "rel=[" . nvim_win_get_config(0).relative . "]"' Enter
smoke_expect 'rel=\[\]'
smoke_reject 'E[0-9]+:'
smoke_stop
smoke_rmdir "$tmp"
echo "mouse smoke: ok"
