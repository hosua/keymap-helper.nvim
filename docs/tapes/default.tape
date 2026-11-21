# default.png: zero-config setup {}, list opened with the default <leader>km.
# Regenerate: bash docs/tapes/capture.sh default      Rows: F01 F09 (FEATURES.md)
# Needs: vhs (ttyd, ffmpeg), nvim >= 0.11. The demo config is docs/tapes/demo/default/.
Source "docs/tapes/common.tape"
Output "/tmp/kmh-demo/discard-default.gif"
Hide
Type 'cd $KMH_DEMO/demo/work && export PS1="$ " && clear'
Enter
Type "nvim hello.lua"
Enter
Sleep 7s
Show
Space
Type "km"
Sleep 800ms
Enter
Sleep 800ms
Screenshot "docs/media/default.png"
Sleep 1s
