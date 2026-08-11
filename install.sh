#!/bin/bash
# Home Board — one-shot Pi bootstrap.
# Run this ONCE, over SSH, right after first boot. Reboots itself at the end.
set -euo pipefail

# --- EDIT THIS before running -------------------------------------------
REPO_URL="https://github.com/YOUR-USERNAME/homeboard.git"
# --------------------------------------------------------------------------

APP_DIR="/home/pi/homeboard"
SETUP_DIR="$APP_DIR/pi-setup"
CONFIG_TXT="/boot/firmware/config.txt"
[ -f "$CONFIG_TXT" ] || CONFIG_TXT="/boot/config.txt"   # pre-Bookworm path fallback

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
cp "$SETUP_DIR/xinitrc" /home/pi/.xinitrc
chmod +x /home/pi/.xinitrc
if ! grep -q "startx -- -nocursor" /home/pi/.bash_profile 2>/dev/null; then
  cat "$SETUP_DIR/bash_profile_append.sh" >> /home/pi/.bash_profile
fi

echo "==> Installing systemd services"
sudo cp "$SETUP_DIR/homeboard.service" /etc/systemd/system/
sudo cp "$SETUP_DIR/homeboard-update.service" /etc/systemd/system/
sudo cp "$SETUP_DIR/homeboard-update.timer" /etc/systemd/system/
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
