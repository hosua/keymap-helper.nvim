#!/usr/bin/env bash
# docs/tapes/capture_tui.sh - regenerate the terminal UI media in docs/media/.
#
#   bash docs/tapes/capture_tui.sh
#
# Shots: tui-import.png (no template yet), tui-picker.png (move to...), tui-overview.png
# (three panes with a few categories), tui-save.png (save summary), tui-saved.png (result
# with both backups), tui-flow.gif (the whole walk-through).
# Needs: vhs (+ ttyd, ffmpeg, chromium), bun, nvim >= 0.11. The UI runs on a copy of
# tests/fixtures/user_mappings.lua in /tmp/kmh-tui, so no real config is touched.
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
DEMO=/tmp/kmh-tui
rm -rf "$DEMO"
mkdir -p "$DEMO/root/lua"
cp "$REPO/tests/fixtures/user_mappings.lua" "$DEMO/root/lua/mappings.lua"
(cd "$REPO/tui" && bun install --frozen-lockfile >/dev/null)
export KMH_REPO="$REPO" KMH_DEMO="$DEMO"
for d in "$HOME/.local/share/nvim/lazy/plenary.nvim" "$HOME/dev/hosua/nvim/submodules/plenary.nvim" "$REPO/.tests/plenary.nvim"; do
  [[ -d $d ]] && { export PLENARY_DIR="$d"; break; }
done
(cd "$REPO" && vhs docs/tapes/tui.tape)
rm -rf "$DEMO"
