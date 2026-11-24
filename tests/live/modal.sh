#!/usr/bin/env bash
# Live check that the keymap list is modal, with the real config copied to a
# temp tree: a mouse click and <C-w>w leave focus in the list, <Esc> does not
# close it, :KeymapHelper close does, and q does. Nothing real is written.
set -u
LIVE_ISOLATE="keymap-helper"
S=${NVIM_PLUGIN_SCRIPTS:-$HOME/.config/nvim/.claude/skills/nvim-create-and-integrate-plugin/scripts}
# shellcheck source=/dev/null
source "${S}/live_lib.sh"
fail=0
chk() { "$@" || fail=1; }

live_setup
CFG_SRC=$(readlink -f "${HOME}/.config/nvim")
mkdir -p "${LIVE_TMP}/cfg/nvim"
rsync -a --exclude=.git --exclude=.claude "${CFG_SRC}/" "${LIVE_TMP}/cfg/nvim/"
smoke_start 160 44 env XDG_CONFIG_HOME="${LIVE_TMP}/cfg" XDG_DATA_HOME="${LIVE_TMP}/data" \
  XDG_STATE_HOME="${LIVE_TMP}/state" nvim -c 'set mouse=a' -c vsplit
sleep 3
click() { # click <col> <row>
  tmux -L "$SMOKE_SOCK" send-keys -l $'\e[<0;'"$1;$2"'M'
  tmux -L "$SMOKE_SOCK" send-keys -l $'\e[<0;'"$1;$2"'m'
  sleep 1
}
rel() { smoke_keys ':echo "rel=[" . nvim_win_get_config(0).relative . "]"' Enter; }

smoke_keys ':KeymapHelper' Enter
sleep 1
chk smoke_expect 'How to read this list'
click 2 2
rel
chk smoke_expect 'rel=\[editor\]'
smoke_keys C-w w
rel
chk smoke_expect 'rel=\[editor\]'
smoke_keys ':wincmd p' Enter
rel
chk smoke_expect 'rel=\[editor\]'
smoke_keys Escape
chk smoke_expect 'How to read this list'
smoke_keys ':KeymapHelper' Enter
chk smoke_reject 'E[0-9]+:'
smoke_keys ':KeymapHelper close' Enter
sleep 1
chk smoke_reject 'How to read this list'
smoke_keys ':KeymapHelper' Enter
sleep 1
chk smoke_expect 'How to read this list'
smoke_type q
sleep 1
chk smoke_reject 'How to read this list'
rel
chk smoke_expect 'rel=\[\]'
live_teardown
exit $fail
