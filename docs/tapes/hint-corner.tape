# hint-corner.png: hint.position = "bottom_right" with a custom message.
# Regenerate: bash docs/tapes/capture.sh hint-corner      Rows: F26
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-hint-corner.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 1500ms
Show
Sleep 300ms
Screenshot "docs/media/hint-corner.png"
Sleep 1s
