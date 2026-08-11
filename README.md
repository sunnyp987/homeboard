# The Home Board — Pi kit

Everything needed to go from a blank SD card to a running kiosk, plus a way to push
dashboard updates afterward without touching the Pi again.

## What's in here

```
index.html          the dashboard itself — this is what gets pushed for updates
pi-setup/
  install.sh         one-shot bootstrap script (run once, over SSH)
  homeboard.service          serves index.html on port 8080
  homeboard-update.service   pulls the latest git commit
  homeboard-update.timer     runs the pull every 5 minutes
  xinitrc            kiosk launch script (installed as ~/.xinitrc)
  bash_profile_append.sh     auto-starts X on console login
```

## One-time setup

**1. Put this in a git repo.**
Create a repo (GitHub, public is fine — there are no secrets in here, see `.gitignore`
for where future API keys go) and push this whole folder to it. Then open
`pi-setup/install.sh` and set `REPO_URL` at the top to that repo's URL.

**2. Flash the SD card.**
Use Raspberry Pi Imager, choose Raspberry Pi OS Lite (64-bit), and before writing, click
the gear icon (⚙) to set: hostname (e.g. `homeboard`), enable SSH, set a username/password,
and your Wi-Fi credentials. This is the only manual step — it means the Pi comes up on
your network with SSH already on, no monitor/keyboard needed.

**3. Boot it, then run the bootstrap once.**
Put the card in the Pi, power it on, wait ~60 seconds, then from your laptop or phone:

```bash
ssh pi@homeboard.local
curl -O https://raw.githubusercontent.com/YOUR-USERNAME/homeboard/main/pi-setup/install.sh
chmod +x install.sh
./install.sh
```

(Or just `git clone` the repo first and run `pi-setup/install.sh` from inside it —
same result.) It installs everything, sets up the kiosk, and reboots on its own.
When it comes back up, the dashboard is on screen. You never need to SSH in again
for normal use.

## Pushing updates later

Edit `index.html` (layout, colors, new sections — whatever), commit, and push to the
repo from wherever you're working:

```bash
git add index.html
git commit -m "tweak meal plan layout"
git push
```

Within 5 minutes, `homeboard-update.timer` on the Pi pulls the new commit, and the
dashboard's own auto-refresh (baked into `index.html`) reloads the page and picks it
up — no SSH, no physical access. Worst case it's on screen within ~10 minutes of your
push.

If you ever need a bigger change (new systemd unit, OS package), that's the one
case you'd SSH in for — everything content-level goes through git.
