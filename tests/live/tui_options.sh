#!/usr/bin/env bash
# Live check of the TUI options screen (O, Truecolor). The TUI reads no nvim
# config, so the root is a COPY of the user fixture under a temp dir and
# XDG_STATE_HOME is throwaway: the real mappings.lua and ~/.local/state are
# never touched.
set -u
LIVE_ISOLATE="keymap-helper"
S=${NVIM_PLUGIN_SCRIPTS:-$HOME/.config/nvim/.claude/skills/nvim-create-and-integrate-plugin/scripts}
# shellcheck source=/dev/null
source "${S}/live_lib.sh"
REPO=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
chk() { "$@" || fail=1; }
live_setup
root="${LIVE_TMP}/root"
mkdir -p "${root}/lua" "${LIVE_TMP}/state"
cp "${REPO}/tests/fixtures/user_mappings.lua" "${root}/lua/mappings.lua"
state="${LIVE_TMP}/state/nvim/keymap-helper/tui.json"
start() { # width height extra-args...
  local w=$1 h=$2; shift 2
  smoke_start "$w" "$h" env XDG_CONFIG_HOME="${LIVE_TMP}/c" XDG_DATA_HOME="${LIVE_TMP}/d" \
    XDG_STATE_HOME="${LIVE_TMP}/state" XDG_CACHE_HOME="${LIVE_TMP}/x" COLORTERM=truecolor \
    bun "${REPO}/tui/src/index.tsx" --root "${root}" "$@"
  sleep 3
}
for size in "80 24" "140 40"; do
  rm -f "${state}"
  # shellcheck disable=SC2086
  start $size
  smoke_type O
  chk smoke_expect '← +True +→'
  chk smoke_expect 'Truecolor'
  chk smoke_reject 'E[0-9]+:'
  smoke_type l
  chk smoke_expect '← +False +→'
  [ "$(cat "${state}")" = '{"truecolor":false}' ] || { echo "state file wrong"; fail=1; }
  smoke_keys Escape
  chk smoke_reject 'Truecolor'
  smoke_stop
done
# restart honours the saved False; the flag beats it
start 80 24; smoke_type O; chk smoke_expect '← +False +→'; smoke_stop
start 80 24 --truecolor=true; smoke_type O; chk smoke_expect '← +True +→'; smoke_stop
live_teardown
exit "${fail}"
