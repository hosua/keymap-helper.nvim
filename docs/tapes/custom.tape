# custom.png: the README's NvChad example: Custom (grouped by header) open, NvChad defaults
# folded, implicit folded "Default" at the end.
# Regenerate: bash docs/tapes/capture.sh custom      Rows: F01 F10 F11 F12 F30
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-custom.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 7s
Space
Type "km"
Sleep 500ms
Enter
Sleep 500ms
Show
Sleep 500ms
Screenshot "docs/media/custom.png"
Sleep 1s
