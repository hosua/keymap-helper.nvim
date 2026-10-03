# health.png: :KeymapHelper health (= :checkhealth keymap-helper) with track() active.
# Regenerate: bash docs/tapes/capture.sh health      Rows: F04 F28
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-health.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 7s
Type ":KeymapHelper health"
Enter
Sleep 2s
Show
Sleep 500ms
Screenshot "docs/media/health.png"
Sleep 1s
