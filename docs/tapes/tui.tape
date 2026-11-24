# tui-*.png and tui-flow.gif: the terminal UI on a throwaway copy of the fixture.
# Regenerate: bash docs/tapes/capture_tui.sh
Require bun
Set Shell "bash"
Set FontSize 14
Set Width 1400
Set Height 820
Set Padding 10
Set Framerate 20
Set TypingSpeed 70ms
Set Theme "Catppuccin Mocha"
Set CursorBlink false
Output "docs/media/tui-flow.gif"
Hide
Type 'cd $KMH_DEMO && export PS1="$ " && clear'
Enter
Type 'bun $KMH_REPO/tui/src/index.tsx --root $KMH_DEMO/root'
Enter
Sleep 3s
Show
Sleep 800ms
Screenshot "docs/media/tui-import.png"
Sleep 1s
Type "y"
Sleep 1500ms
Type "l"
Sleep 400ms
Space@250ms 4
Sleep 300ms
Type "m"
Sleep 600ms
Type "Navigation"
Sleep 700ms
Screenshot "docs/media/tui-picker.png"
Sleep 1s
Enter
Sleep 800ms
Type "V"
Type@200ms "jjjj"
Type "m"
Sleep 400ms
Type "Git"
Sleep 400ms
Enter
Sleep 800ms
Type "m"
Sleep 400ms
Type "nav"
Sleep 500ms
Enter
Sleep 600ms
Type "h"
Type@200ms "jj"
Sleep 400ms
Type "l"
Sleep 700ms
Screenshot "docs/media/tui-overview.png"
Sleep 1s
Type "w"
Sleep 800ms
Screenshot "docs/media/tui-save.png"
Sleep 1s
Type "y"
Sleep 2s
Screenshot "docs/media/tui-saved.png"
Sleep 1s
Type "x"
Sleep 600ms
Type "q"
Sleep 800ms
