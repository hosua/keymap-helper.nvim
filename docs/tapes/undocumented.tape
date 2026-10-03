# undocumented.png: show_undocumented = true lists maps that have no desc.
# Regenerate: bash docs/tapes/capture.sh undocumented      Rows: F23
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-undocumented.gif"
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
Screenshot "docs/media/undocumented.png"
Sleep 1s
