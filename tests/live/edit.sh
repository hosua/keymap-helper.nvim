#!/usr/bin/env bash
# Live check of `:KeymapHelper edit` with the real config, on a COPY of it:
# the float opens over the real session, the live snapshot finds NvChad's
# <leader>h default overridden by the template, and q closes the float.
# Plugins are symlinked from ~/.local/share/nvim by live_lib.sh; nothing is
# written to the real config or its data.
set -u
LIVE_ISOLATE="keymap-helper"
S=${NVIM_PLUGIN_SCRIPTS:-$HOME/.config/nvim/.claude/skills/nvim-create-and-integrate-plugin/scripts}
# shellcheck source=/dev/null
source "${S}/live_lib.sh"
fail=0
# shellcheck source=tests/ready_lib.sh
source "$(dirname "$0")/../ready_lib.sh"
chk() { "$@" || fail=1; }

live_setup
CFG_SRC=$(readlink -f "${HOME}/.config/nvim")
mkdir -p "${LIVE_TMP}/cfg/nvim"
rsync -a --exclude=.git --exclude=.claude "${CFG_SRC}/" "${LIVE_TMP}/cfg/nvim/"
smoke_start 160 44 env XDG_CONFIG_HOME="${LIVE_TMP}/cfg" XDG_DATA_HOME="${LIVE_TMP}/data" \
  XDG_STATE_HOME="${LIVE_TMP}/state" nvim
live_wait_nvim
smoke_keys ':KeymapHelper import' Enter
sleep 1
chk smoke_expect 'imported [0-9]+ maps'
smoke_keys ':KeymapHelper generate!' Enter
sleep 1
smoke_keys ':KeymapHelper edit' Enter
live_wait_screen '[0-9]+ overrides?' 40
chk smoke_expect 'keymap-helper edit'
chk smoke_expect 'Categories'
chk smoke_expect '[0-9]+ overrides?'
chk smoke_expect 'defaults read as text'
chk smoke_reject 'E[0-9]+:'
smoke_type ']c'
chk smoke_expect 'conflict 1/'
smoke_type q
sleep 2
chk smoke_reject 'Categories'
live_teardown
exit $fail
