# hint.png: the centered startup hint, shown right after nvim starts.
# Regenerate: bash docs/tapes/capture.sh hint      Rows: F06
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-hint.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 1500ms
Show
Sleep 300ms
Screenshot "docs/media/hint.png"
Sleep 1s
