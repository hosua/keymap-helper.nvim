#!/usr/bin/env bash
# docs/tapes/capture_conflicts.sh - regenerate tui-conflicts.png, tui-duplicate.png and
# edit-float.png in docs/media/.
#
#   bash docs/tapes/capture_conflicts.sh
#
# Needs: vhs (+ ttyd, ffmpeg, chromium), bun, nvim >= 0.11. Runs on a copy of
# docs/tapes/demo/conflicts in /tmp/kmh-conf, with XDG_* pointed there too, so no real
# config or data is touched. The demo config is a stand-in for NvChad (see its init.lua).
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
DEMO=/tmp/kmh-conf
rm -rf "$DEMO"
mkdir -p "$DEMO/xdg/config" "$DEMO/xdg/data" "$DEMO/xdg/state" "$DEMO/xdg/cache"
cp -r "$REPO/docs/tapes/demo/conflicts" "$DEMO/xdg/config/nvim"
(cd "$REPO/tui" && bun install --frozen-lockfile >/dev/null)
export KMH_REPO="$REPO" KMH_DEMO="$DEMO"
export XDG_CONFIG_HOME="$DEMO/xdg/config" XDG_DATA_HOME="$DEMO/xdg/data" XDG_STATE_HOME="$DEMO/xdg/state" XDG_CACHE_HOME="$DEMO/xdg/cache"
for d in "$HOME/.local/share/nvim/lazy/plenary.nvim" "$HOME/dev/hosua/nvim/submodules/plenary.nvim" "$REPO/.tests/plenary.nvim"; do
  [[ -d $d ]] && { export PLENARY_DIR="$d"; break; }
done
for d in "$HOME/dev/hosua/nvim/submodules/popup.nvim" "$REPO/.tests/popup.nvim"; do
  [[ -d $d ]] && { export POPUP_DIR="$d"; break; }
done
# Import once, so the template exists before the shots start.
"$REPO/scripts/kh-import" --root="$DEMO/xdg/config/nvim" --yes >/dev/null
(cd "$REPO" && vhs docs/tapes/conflicts.tape && vhs docs/tapes/edit.tape)
rm -rf "$DEMO"
