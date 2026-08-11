#!/bin/bash
# Home Board — one-shot Pi bootstrap.
# Run this ONCE, over SSH, right after first boot. Reboots itself at the end.
set -euo pipefail

REPO_URL="https://github.com/sunnyp987/homeboard.git"
APP_USER="homeboard"
APP_DIR="/home/$APP_USER/homeboard"
CONFIG_TXT="/boot/firmware/config.txt"
[ -f "$CONFIG_TXT" ] || CONFIG_TXT="/boot/config.txt"

echo "==> Updating system packages"
sudo apt update
sudo apt full-upgrade -y

echo "==> Installing kiosk + git dependencies"
# cage = minimal Wayland kiosk compositor. Deliberately NOT X11/xinit:
# on Bookworm + Pi 2, the Xorg modesetting handoff leaves the display black
# even though Xorg reports a valid 1080p mode and logs no errors.
sudo apt install --no-install-recommends -y cage chromium-browser git python3-pip

echo "==> Installing calendar parsing libraries"
# --break-system-packages: Bookworm marks the system Python externally managed
# (PEP 668). This board is a single-purpose appliance, so installing into the
# system interpreter is fine and avoids a venv the systemd units would have to
# know about. recurring-ical-events is what expands RRULEs — without it every
# repeating event silently vanishes from the board.
sudo pip3 install --break-system-packages icalendar recurring-ical-events

echo "==> Fetching the dashboard"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$APP_DIR"
fi

echo "==> Installing kiosk autostart"
if ! grep -q "cage --" "/home/$APP_USER/.bash_profile" 2>/dev/null; then
  cat "$APP_DIR/bash_profile_append.sh" >> "/home/$APP_USER/.bash_profile"
fi

echo "==> Installing systemd services"
sudo cp "$APP_DIR"/homeboard.service /etc/systemd/system/
sudo cp "$APP_DIR"/homeboard-update.service /etc/systemd/system/
sudo cp "$APP_DIR"/homeboard-update.timer /etc/systemd/system/
sudo cp "$APP_DIR"/homeboard-data.service /etc/systemd/system/
sudo cp "$APP_DIR"/homeboard-data.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable homeboard.service
sudo systemctl enable homeboard-update.timer
sudo systemctl enable homeboard-data.timer

echo "==> Enabling console auto-login (needed for the kiosk to start unattended)"
sudo raspi-config nonint do_boot_behaviour B2

echo "==> Boot config: force HDMI output even when no display is attached at boot"
if ! grep -q "hdmi_force_hotplug" "$CONFIG_TXT" 2>/dev/null; then
  echo "hdmi_force_hotplug=1" | sudo tee -a "$CONFIG_TXT" > /dev/null
fi

echo "==> Disabling the Pi's activity LED"
if ! grep -q "dtparam=act_led_trigger" "$CONFIG_TXT" 2>/dev/null; then
  {
    echo "dtparam=act_led_trigger=none"
    echo "dtparam=act_led_activelow=off"
  } | sudo tee -a "$CONFIG_TXT" > /dev/null
fi

if [ ! -f "$APP_DIR/config.json" ]; then
  echo
  echo "!! No config.json yet — the board will show a correct calendar with no events."
  echo "!! Create it with your secret iCal URL, then: sudo systemctl start homeboard-data"
  echo
fi

echo "==> Done. Rebooting into the kiosk in 5 seconds..."
sleep 5
sudo reboot
