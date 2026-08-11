# Appended to ~/.bash_profile by install.sh — auto-starts X on the console login.
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx -- -nocursor
fi
