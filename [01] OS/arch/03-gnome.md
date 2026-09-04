# 3 — GNOME (no group install)

```bash
# Tier 0
sudo pacman -S --needed \
  gnome-shell gdm gnome-control-center gnome-keyring gnome-backgrounds \
  noto-fonts wireplumber pipewire-jack power-profiles-daemon
sudo systemctl enable gdm.service power-profiles-daemon.service
sudo systemctl enable bluetooth.service        # bluez is pulled by gnome-control-center

# Tier 1
sudo pacman -S --needed \
  gnome-console gnome-text-editor loupe papers file-roller 7zip unrar gnome-calculator \
  gnome-disk-utility gnome-system-monitor gnome-tweaks \
  extension-manager gnome-shell-extension-appindicator \
  gst-plugin-pipewire gst-thumbnailers gst-libav noto-fonts-emoji

# Tier 2: pick
sudo pacman -S --needed showtime decibels snapshot gst-plugins-bad gst-plugins-ugly gst-plugin-va
sudo pacman -S --needed gnome-clocks gnome-weather gnome-characters gnome-font-viewer gnome-logs baobab
sudo pacman -S --needed gnome-calendar gnome-contacts          # pulls evolution-data-server
sudo pacman -S --needed gvfs-mtp gvfs-smb seahorse dconf-editor
sudo pacman -S --needed gnome-shell-extension-dash-to-dock gnome-shell-extension-no-overview gnome-shell-extension-caffeine gnome-shell-extension-vitals
sudo pacman -S --needed flatpak                                # CLI only; do NOT install gnome-software
sudo pacman -S --needed cups system-config-printer && sudo systemctl enable cups.socket
```

Already pulled in by `gnome-shell` (don't list): gnome-session, gnome-settings-daemon, mutter, nautilus, gvfs, localsearch/tinysparql, xdg-desktop-portal(-gnome,-gtk), pipewire, pipewire-pulse, xorg-xwayland, adwaita-fonts, gcr-4. GNOME 50 is Wayland-only.

Skip: gnome-software, gnome-tour, gnome-initial-setup, yelp/gnome-user-docs, gnome-user-share, rygel, orca, malcontent, sushi, totem/evince/cheese, switcheroo-control, polkit-gnome, the `gnome`/`gnome-extra` groups.

After first login:

```bash
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.shell welcome-dialog-last-shown-version '50.4'
systemctl --user enable --now gcr-ssh-agent.socket
# FAST / HDD root: no indexing
gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories "[]"
gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories "[]"
gsettings set org.freedesktop.Tracker3.Miner.Files enable-monitors false
cp /etc/xdg/autostart/localsearch-3.desktop ~/.config/autostart/ && echo Hidden=true >> ~/.config/autostart/localsearch-3.desktop

# HDD root: profile-sync-daemon. cachyos-settings' 10 s user-service stop timeout kills the shutdown write-back of a big Firefox profile → next boot restores the last hourly copy (browser logins gone). Raise it BEFORE enabling.
sudo pacman -S --needed profile-sync-daemon
mkdir -p ~/.config/systemd/user/psd.service.d && printf '[Service]\nTimeoutStopSec=120\n' > ~/.config/systemd/user/psd.service.d/override.conf
systemctl --user daemon-reload && systemctl --user enable --now psd.service
# check after the first reboot: journalctl --user -u psd.service | grep -E 'timed out|Ungraceful'   → must be empty
```

Autologin: `/etc/gdm/custom.conf` → `[daemon]` `AutomaticLoginEnable=True` `AutomaticLogin=<user>`. Empty user list on the GDM 50 greeter: [notes §3](./99-notes.md#3-desktops).
