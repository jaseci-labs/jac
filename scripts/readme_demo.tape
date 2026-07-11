# VHS tape for the README hero demo GIF.
#
# Records the install -> create -> start flow as an animated GIF.
# Requires VHS (https://github.com/charmbracelet/vhs):  brew install vhs
#
# Record with:
#   vhs scripts/readme_demo.tape
#
# Then swap the <picture> block at the top of README.md to point at the GIF:
#   docs/docs/assets/readme/demo.gif
#
# Run this from a machine WITHOUT jac installed (or a container) so the
# install step records honestly.

Output docs/docs/assets/readme/demo.gif

Set FontSize 16
Set Width 1100
Set Height 560
Set Padding 16
Set TypingSpeed 35ms
Set Theme "Builtin Dark"

Type "curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash"
Enter
Sleep 8s

Type "jac create myapp --kind web-app"
Enter
Sleep 4s

Type "cd myapp && jac install"
Enter
Sleep 10s

Type "jac start"
Enter
Sleep 10s

Sleep 3s
