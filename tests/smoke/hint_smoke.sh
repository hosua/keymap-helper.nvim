#!/usr/bin/env bash
# The startup hint toast is centered by default, at two terminal sizes.
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/smoke/lib.sh
tmp=$(mktemp -d)
env_xdg=(env XDG_CONFIG_HOME="$tmp/c" XDG_DATA_HOME="$tmp/d" XDG_STATE_HOME="$tmp/s" XDG_CACHE_HOME="$tmp/x")
trap 'smoke_stop; smoke_rmdir "$tmp"' EXIT

fail=0
check_centered() {
  local w=$1 h=$2
  smoke_start "$w" "$h" "${env_xdg[@]}" nvim --clean -u tests/smoke/init.lua
  smoke_expect 'Type <leader>km' || { fail=1; return; }
  smoke_reject 'E[0-9]+:' || fail=1
  local res
  res=$(smoke_screen | W=$w H=$h python3 -c '
import os, sys
w, h = int(os.environ["W"]), int(os.environ["H"])
lines = sys.stdin.read().split("\n")
for i, l in enumerate(lines):
    if "Type <leader>km" in l:
        # empty-buffer filler: the "~" in column 0 is not part of the box
        if l.startswith("~"):
            l = " " + l[1:]
        l = l.rstrip()
        left = len(l) - len(l.lstrip())
        right = w - len(l)
        print(i, left, right)
        break
else:
    print("none")
')
  if [ "$res" = none ]; then echo "  FAIL  ${w}x${h}: hint line not found"; fail=1; smoke_stop; return; fi
  read -r row left right <<<"$res"
  local mid=$((h / 2)) dr dm
  dr=$((row > mid ? row - mid : mid - row))
  dm=$((left > right ? left - right : right - left))
  if [ "$dr" -le 2 ]; then echo "  ok    ${w}x${h}: hint row $row within 2 of middle $mid"
  else echo "  FAIL  ${w}x${h}: hint row $row is $dr rows from middle $mid"; fail=1; fi
  if [ "$dm" -le 4 ]; then echo "  ok    ${w}x${h}: margins left=$left right=$right differ by <= 4"
  else echo "  FAIL  ${w}x${h}: margins left=$left right=$right differ by $dm"; fail=1; fi
  smoke_stop
}

check_centered 80 24
check_centered 200 50

[ "$fail" = 0 ] || exit 1
echo "hint smoke: ok"
