# commands.gif: :KeymapHelper hint, an unknown subcommand, then a bare :KeymapHelper and q.
# Regenerate: bash docs/tapes/capture.sh commands      Rows: F02 F03 F05 F17
Source "docs/tapes/common.tape"
Output "docs/media/commands.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 7s
Show
Sleep 800ms
Type ":KeymapHelper hint"
Sleep 600ms
Enter
Sleep 2s
Type ":KeymapHelper bogus"
Sleep 600ms
Enter
Sleep 2500ms
Type ":KeymapHelper"
Sleep 600ms
Enter
Sleep 2s
Type "q"
Sleep 2s
