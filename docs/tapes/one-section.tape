# one-section.png: the one-line config (only "NvChad defaults", folded) plus the implicit Default.
# Regenerate: bash docs/tapes/capture.sh one-section      Rows: F13
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-one-section.gif"
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
Screenshot "docs/media/one-section.png"
Sleep 1s
