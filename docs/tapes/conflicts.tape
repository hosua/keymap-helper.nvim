# tui-conflicts.png and tui-duplicate.png.
# Regenerate: bash docs/tapes/capture_conflicts.sh
Require bun
Require nvim
Set Shell "bash"
Set FontSize 14
Set Width 1400
Set Height 820
Set Padding 10
Set Framerate 20
Set TypingSpeed 70ms
Set Theme "Catppuccin Mocha"
Set CursorBlink false
Output "/tmp/kmh-conf/unused.gif"
Hide
Type 'cd $KMH_DEMO && export PS1="$ " && clear'
Enter
Type 'bun $KMH_REPO/tui/src/index.tsx --root $KMH_DEMO/xdg/config/nvim'
Enter
Sleep 5s
Show
Type "]c"
Sleep 400ms
Type "l"
Sleep 800ms
Screenshot "docs/media/tui-conflicts.png"
Sleep 600ms
Type "]c"
Sleep 400ms
Type "]c"
Sleep 800ms
Screenshot "docs/media/tui-duplicate.png"
Sleep 600ms
Type "q"
Sleep 800ms
