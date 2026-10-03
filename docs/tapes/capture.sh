#!/usr/bin/env bash
# docs/tapes/capture.sh - regenerate the README media in docs/media/.
#
# Usage (from anywhere inside the repo):
#   bash docs/tapes/capture.sh                 # every shot in DEFAULT_SHOTS, in order
#   bash docs/tapes/capture.sh custom hint     # only the named shot(s)
#
# Shots (slug -> file, what it shows, FEATURES.md ids; keep in sync with DEFAULT_SHOTS):
#   default          default.png          zero-config setup {}, <leader>km, one "Default" section  (F01 F09)
#   custom           custom.png           NvChad example: Custom by header, NvChad folded, Default   (F10 F11 F12 F30)
#   one-section      one-section.png      one-line config: NvChad defaults + implicit Default        (F13)
#   intro            intro.png            "How to read this list" legend expanded                    (F07)
#   hint             hint.png             centered startup hint                                      (F06)
#   hint-corner      hint-corner.png      hint.position = "bottom_right" + custom message            (F26)
#   group-by         group-by.png         lhs-filtered section + group_by = "leader_prefix"          (F19 F20 F21)
#   undocumented     undocumented.png     show_undocumented = true                                   (F23)
#   health           health.png           :KeymapHelper health, track() active                       (F04 F28)
#   nvchad-submenu   nvchad-submenu.gif   <CR> expands NvChad defaults, zM, zR                       (F14 F16)
#   fold-keys        fold-keys.gif        l, h, za, <Tab>, <Esc>                                     (F08 F15 F17)
#   commands         commands.gif         :KeymapHelper hint / bogus / bare, q                       (F02 F03 F05 F17)
#
# Coverage of every feature: docs/tapes/FEATURES.md
# Needs: vhs (+ ttyd, ffmpeg, chromium), nvim >= 0.11. No X display needed (vhs is headless).
# Every shot runs nvim with HOME and XDG_* in a throwaway /tmp/kmh-demo, using the demo configs in
# docs/tapes/demo/<variant>/; the real ~/.config/nvim and ~/.local/share/nvim are never touched.
# Shots run sequentially on purpose (one demo dir).
set -euo pipefail

DEFAULT_SHOTS=(default custom one-section intro hint hint-corner group-by undocumented health nvchad-submenu fold-keys commands)

REPO="$(git rev-parse --show-toplevel)"
DEMO=/tmp/kmh-demo # the only path that may appear in frames

# shot slug -> demo config variant (docs/tapes/demo/<variant>)
variant_of() {
  case "$1" in
    default) echo default ;;
    custom | intro | health | nvchad-submenu | fold-keys | commands) echo custom ;;
    one-section | group-by | undocumented | hint-corner) echo "$1" ;;
    hint) echo default ;;
    *) echo "unknown shot: $1 (known: ${DEFAULT_SHOTS[*]})" >&2; return 2 ;;
  esac
}

fresh_demo() { # fresh_demo <variant>: throwaway HOME/XDG, config = the variant, plugin = this checkout
  rm -rf "$DEMO"
  mkdir -p "$DEMO"/{home,config,data,state,cache,plugins}
  ln -s "$REPO" "$DEMO/plugins/keymap-helper.nvim" # so frames show /tmp/..., not the checkout path
  cp -r "$REPO/docs/tapes/demo" "$DEMO/demo"
  ln -s "$DEMO/demo/$1" "$DEMO/config/nvim"
}

shot() {
  local slug=$1 variant
  variant=$(variant_of "$slug")
  fresh_demo "$variant"
  export HOME="$DEMO/home" XDG_CONFIG_HOME="$DEMO/config" XDG_DATA_HOME="$DEMO/data" \
    XDG_STATE_HOME="$DEMO/state" XDG_CACHE_HOME="$DEMO/cache" \
    KMH_REPO="$DEMO/plugins/keymap-helper.nvim" KMH_DEMO="$DEMO" KMH_TRACK=0
  [[ $slug == health ]] && export KMH_TRACK=1
  (cd "$REPO" && vhs "docs/tapes/$slug.tape")
}

for s in "${@:-${DEFAULT_SHOTS[@]}}"; do
  echo "== $s"
  shot "$s"
done
rm -rf "$DEMO"
