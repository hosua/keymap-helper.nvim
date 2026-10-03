# fold-keys.gif: the other fold keys: l (open), h (close), za and <Tab> (toggle), then <Esc> closes.
# Regenerate: bash docs/tapes/capture.sh fold-keys      Rows: F08 F15 F17
Source "docs/tapes/common.tape"
Output "docs/media/fold-keys.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 7s
Space
Type "km"
Sleep 500ms
Show
Sleep 1500ms
Enter
Sleep 1500ms
Type "jj"
Sleep 800ms
Type "h"
Sleep 1500ms
Type "l"
Sleep 1500ms
Type "za"
Sleep 1500ms
Tab
Sleep 1500ms
Escape
Sleep 2s
