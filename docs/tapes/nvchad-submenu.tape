# nvchad-submenu.gif: move to "NvChad defaults", <CR> expands it, then zM (close all), zR (open all).
# Regenerate: bash docs/tapes/capture.sh nvchad-submenu      Rows: F14 F16
Source "docs/tapes/common.tape"
Output "docs/media/nvchad-submenu.gif"
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
Sleep 400ms
Show
Sleep 1500ms
Type "G"
Sleep 800ms
Type "kkkk"
Sleep 1200ms
Enter
Sleep 2500ms
Type "zM"
Sleep 2s
Type "zR"
Sleep 3s
