# group-by.png: lhs-filtered section, group_by = "plugin", group_by = "leader_prefix".
# Regenerate: bash docs/tapes/capture.sh group-by      Rows: F19 F20 F21
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-group-by.gif"
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
Screenshot "docs/media/group-by.png"
Sleep 1s
