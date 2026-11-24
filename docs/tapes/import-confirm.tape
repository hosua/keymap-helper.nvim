# import-confirm.png: :KeymapHelper import when the template no longer matches lua/mappings.lua.
# Regenerate: bash docs/tapes/capture.sh import-confirm
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-import-confirm.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 7s
Type ":KeymapHelper import"
Enter
Sleep 1500ms
Show
Sleep 500ms
Screenshot "docs/media/import-confirm.png"
Sleep 1s
