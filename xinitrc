#!/bin/sh
# Installed as ~/.xinitrc — launches the kiosk browser on X start.
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.5 -root &
chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --check-for-update-interval=31536000 \
  --incognito \
  http://localhost:8080
