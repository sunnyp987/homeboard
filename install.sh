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
sudo apt install --no-install-recommends -y \
  xserver-xorg x11-xserver-utils xinit chromium-browser unclutter git

echo "==> Fetching the dashboard"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$APP_DIR"
fi

echo "==> Installing kiosk autostart"
cp "$APP_DIR/xinitrc" "/home/$APP_USER/.xinitrc"
chmod +x "/home/$APP_USER/.xinitrc"
if ! grep -q "startx -- -nocursor" "/home/$APP_USER/.bash_profile" 2>/dev/null; then
  cat "$APP_DIR/bash_profile_append.sh" >> "/home/$APP_USER/.bash_profile"
fi

echo "==> Installing systemd services"
sudo cp "$APP_DIR/homeboard.service" /etc/systemd/system/
sudo cp "$APP_DIR/homeboard-update.service" /etc/systemd/system/
sudo cp "$APP_DIR/homeboard-update.timer" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable homeboard.service
sudo systemctl enable homeboard-update.timer

echo "==> Enabling console auto-login (needed for the kiosk to start unattended)"
sudo raspi-config nonint do_boot_behaviour B2

echo "==> Disabling the Pi's activity LED"
if ! grep -q "dtparam=act_led_trigger" "$CONFIG_TXT" 2>/dev/null; then
  {
    echo "dtparam=act_led_trigger=none"
    echo "dtparam=act_led_activelow=off"
  } | sudo tee -a "$CONFIG_TXT" > /dev/null
fi

echo "==> Done. Rebooting into the kiosk in 5 seconds..."
sleep 5
sudo reboot
