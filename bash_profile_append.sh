# Appended to ~/.bash_profile by install.sh — starts the Wayland kiosk on console login.
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  cage -- chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --check-for-update-interval=31536000 \
    --ozone-platform=wayland \
    --incognito \
    http://localhost:8080
fi
