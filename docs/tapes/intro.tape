# intro.png: the "How to read this list" legend expanded (the default state).
# Regenerate: bash docs/tapes/capture.sh intro      Rows: F07
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-intro.gif"
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
Sleep 500ms
Screenshot "docs/media/intro.png"
Sleep 1s
