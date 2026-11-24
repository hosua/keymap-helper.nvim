#!/usr/bin/env bash
# :KeymapHelper edit in a real nvim: the float opens over the buffer, the TUI
# renders inside it, a move and a save write the template, and q closes the
# float. Then the same command with no bun on PATH must say so in a popup.
# Skipped with a message when bun is not installed.
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! command -v bun >/dev/null 2>&1; then
  echo "edit smoke: bun is not installed, skipping (https://bun.sh)"
  exit 0
fi
(cd tui && bun install --frozen-lockfile >/dev/null)
source tests/smoke/lib.sh
tmp=$(mktemp -d)
mkdir -p "$tmp/c/nvim/lua"
cp tests/fixtures/mappings.lua "$tmp/c/nvim/lua/mappings.lua"
env_xdg=(env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x")
trap 'smoke_stop; smoke_rmdir "$tmp"' EXIT
fail=0
chk() { "$@" || fail=1; }

smoke_start 140 40 "${env_xdg[@]}" nvim --clean -u tests/smoke/init.lua
smoke_keys ':KeymapHelper import drop_headers' Enter
chk smoke_expect 'imported [0-9]+ maps'
smoke_keys ':KeymapHelper edit' Enter
sleep 3
chk smoke_expect 'keymap-helper edit'
chk smoke_expect 'Categories'
chk smoke_expect 'Details'
chk smoke_expect 'jump conflict'
chk smoke_reject 'E[0-9]+:'

# Move one entry to a new category, save, leave.
smoke_keys l
smoke_keys Space
smoke_keys m
smoke_type 'Edit smoke'
smoke_keys Enter
chk smoke_expect 'moved 1 entry to the new category'
smoke_type w
smoke_type y
sleep 2
chk smoke_expect 'template saved'
smoke_type x
smoke_type q
sleep 2
chk smoke_reject 'Categories'
chk smoke_expect 'Restart nvim to load them'
grep -q '"title": "Edit smoke"' "$tmp/c/nvim/lua/mappings.template.json" \
  && echo "  ok    the template has the new category" || { echo "  FAIL  template lacks the category"; fail=1; }
smoke_stop

# No bun on PATH: a popup says so, nothing else opens.
mkdir -p "$tmp/bin"
ln -s "$(command -v nvim)" "$tmp/bin/nvim"
smoke_start 100 30 "${env_xdg[@]}" env PATH="$tmp/bin" "$tmp/bin/nvim" --clean -u tests/smoke/init.lua
smoke_keys ':KeymapHelper edit' Enter
chk smoke_expect 'bun is not on your PATH'
chk smoke_expect 'https://bun.sh'
smoke_keys q
chk smoke_reject 'bun is not on your PATH'

[ "$fail" -eq 0 ] && echo "edit smoke: ok"
exit "$fail"
