# edit-float.png: :KeymapHelper edit in a real nvim.
# Regenerate: bash docs/tapes/capture_conflicts.sh
Require bun
Require nvim
Set Shell "bash"
Set FontSize 14
Set Width 1400
Set Height 820
Set Padding 10
Set Framerate 20
Set TypingSpeed 70ms
Set Theme "Catppuccin Mocha"
Set CursorBlink false
Output "/tmp/kmh-conf/unused-edit.gif"
Hide
Type 'cd $KMH_DEMO && export PS1="$ " && clear'
Enter
Type 'nvim'
Enter
Sleep 3s
Type ":KeymapHelper edit"
Enter
Sleep 4s
Type "]c"
Sleep 400ms
Type "]c"
Sleep 400ms
Show
Sleep 1s
Screenshot "docs/media/edit-float.png"
Sleep 500ms
Hide
Type "q"
Sleep 500ms
Type ":qa!"
Enter
Sleep 500ms
