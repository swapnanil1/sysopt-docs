# 3 — KDE Plasma 6 (no meta packages)

```bash
# Tier 0: core (+ the two providers named so nothing prompts)
sudo pacman -S --needed plasma-desktop qt6-multimedia-ffmpeg pipewire-pulse pipewire-jack

# login manager — ONE of:
sudo pacman -S --needed plasma-login-manager && sudo systemctl enable plasmalogin.service   # KDE's SDDM fork, Arch's default since 6.7, Wayland greeter
# sudo pacman -S --needed sddm sddm-kcm && sudo systemctl enable sddm.service                # mature, pulls xorg-server

# Tier 1: only optional deps of plasma-desktop → must be named
sudo pacman -S --needed \
  kscreen plasma-nm plasma-pa kwallet-pam \
  breeze-gtk kde-gtk-config \
  konsole dolphin kio-admin ffmpegthumbs kate ark 7zip unrar \
  spectacle plasma-systemmonitor \
  power-profiles-daemon python-gobject
sudo systemctl enable power-profiles-daemon.service

# Tier 2: pick
sudo pacman -S --needed gwenview okular kcalc kwalletmanager filelight partitionmanager kinfocenter
sudo pacman -S --needed bluedevil && sudo systemctl enable bluetooth.service
sudo pacman -S --needed kdeconnect kdeplasma-addons plasma-browser-integration plasma-disks kdegraphics-thumbnailers
sudo pacman -S --needed flatpak discover flatpak-kcm        # Discover for Flatpak/fwupd only — never packagekit-qt6
sudo pacman -S --needed cups print-manager && sudo systemctl enable cups.socket
```

Already pulled in by `plasma-desktop` (don't list): plasma-workspace, kwin, systemsettings, powerdevil, polkit-kde-agent, kde-cli-tools, kio-extras, xdg-desktop-portal(-kde), breeze*, baloo, kwallet, xorg-xwayland, pipewire, wireplumber, noto-fonts, ttf-hack, noto-fonts-emoji, mesa, xdg-user-dirs. `kwrite` → `kate`; `qt6-wayland` not needed.

Skip: oxygen*, plasma-welcome, drkonqi, plasma-workspace-wallpapers (254 MiB), plasma-x11-session/kwin-x11, plasma-keyboard, plasma-sdk, kde-applications-meta.

After first login:

```bash
# wallet wizard: "classic blowfish", login password  → kwallet-pam unlocks it
balooctl6 suspend && balooctl6 disable      # FAST / HDD root: no file indexing

# HDD root: profile-sync-daemon. cachyos-settings' 10 s user-service stop timeout kills the shutdown write-back of a big Firefox profile → next boot restores the last hourly copy (browser logins gone). Raise it BEFORE enabling.
sudo pacman -S --needed profile-sync-daemon
mkdir -p ~/.config/systemd/user/psd.service.d && printf '[Service]\nTimeoutStopSec=120\n' > ~/.config/systemd/user/psd.service.d/override.conf
systemctl --user daemon-reload && systemctl --user enable --now psd.service
# check after the first reboot: journalctl --user -u psd.service | grep -E 'timed out|Ungraceful'   → must be empty
```

Dolphin: one extra right-click entry for archives, *Extract here, flat (merge, terminal)* — what Ark's *Extract here* doesn't do: multi-select, everything merged into the current folder, wrapper folders dropped, one terminal per archive ending with "Press any key to close". Files: [`kde/extract-here-flat`](./kde/extract-here-flat) + [`kde/extract-here-flat.desktop`](./kde/extract-here-flat.desktop).

```bash
install -Dm755 kde/extract-here-flat ~/.local/bin/extract-here-flat
sed "s|@HOME@|$HOME|g" kde/extract-here-flat.desktop | install -Dm755 /dev/stdin ~/.local/share/kio/servicemenus/extract-here-flat.desktop
```

Autologin: `/etc/plasmalogin.conf` → `[Autologin]` `User=<user>` `Session=plasma` (same keys in `/etc/sddm.conf.d/autologin.conf`). Package roles: [notes §3](./99-notes.md#3-desktops).
