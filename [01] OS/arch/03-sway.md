# 3 — Sway

```bash
# Tier 0 (ttf-dejavu first: sway needs a ttf-font provider)
sudo pacman -S --needed ttf-dejavu sway swaybg foot wmenu polkit-gnome \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk xorg-xwayland ly pipewire-pulse pipewire-jack
sudo systemctl enable ly@tty1.service && sudo systemctl disable getty@tty1.service

# Tier 1
sudo pacman -S --needed \
  waybar ttf-jetbrains-mono-nerd otf-font-awesome \
  mako swayidle swaylock wl-clipboard cliphist swappy \
  pavucontrol network-manager-applet blueman \
  thunar thunar-volman thunar-archive-plugin xarchiver gvfs gvfs-mtp tumbler \
  mousepad swayimg gnome-keyring xdg-user-dirs xdg-utils \
  nwg-look qt6ct kvantum autotiling jq
# laptop: brightnessctl kanshi      Qt5 apps: qt5ct qt5-wayland kvantum-qt5      launcher alternatives: fuzzel | wofi

# Tier 2: pick
sudo pacman -S --needed wlsunset wdisplays swayosd sway-contrib wtype wlogout
# HDD root: profile-sync-daemon. cachyos-settings' 10 s user-service stop timeout kills the shutdown write-back of a big Firefox profile → next boot restores the last hourly copy (browser logins gone). Raise it BEFORE enabling.
sudo pacman -S --needed profile-sync-daemon
mkdir -p ~/.config/systemd/user/psd.service.d && printf '[Service]\nTimeoutStopSec=120\n' > ~/.config/systemd/user/psd.service.d/override.conf
systemctl --user daemon-reload && systemctl --user enable --now psd.service
# check after the first reboot: journalctl --user -u psd.service | grep -E 'timed out|Ungraceful'   → must be empty
```

Pulled in (don't list / don't enable): wlroots, seatd (**never enable seatd.service**), polkit, grim, slurp, xdg-desktop-portal. Don't install: xf86-video-*, xorg-xhost, flameshot.

`cp /etc/sway/config ~/.config/sway/config`, then add:

```
set $menu wmenu-run
font pango:JetBrainsMono Nerd Font 11
output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
output DP-1 mode 1920x1080@144Hz adaptive_sync on      # swaymsg -t get_outputs
input type:pointer { accel_profile flat pointer_accel 0 }
input type:keyboard xkb_numlock enabled
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec mako
exec nm-applet --indicator
exec blueman-applet
exec wl-paste --watch cliphist store
exec_always autotiling
exec swayidle -w timeout 600 'swaylock -f -c 000000' timeout 900 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' before-sleep 'playerctl pause; swaylock -f -c 000000'
bindsym $mod+Shift+s exec grim -g "$(slurp)" - | swappy -f -
bindsym Print        exec grim -g "$(slurp)" - | wl-copy
bindsym $mod+v       exec cliphist list | wmenu | cliphist decode | wl-copy
bar { swaybar_command waybar }
for_window [app_id="pavucontrol"] floating enable
include /etc/sway/config.d/*        # keep: env import + portal activation ships here
```

`/etc/environment`:

```
QT_QPA_PLATFORMTHEME=qt6ct
QT_QPA_PLATFORM=wayland;xcb
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
_JAVA_AWT_WM_NONREPARENTING=1
```

Do **not** create `~/.config/xdg-desktop-portal/portals.conf` (sway ships one), no `exec gnome-keyring-daemon` (PAM starts it), no `MOZ_ENABLE_WAYLAND`/`GDK_BACKEND`/`ELECTRON_OZONE_PLATFORM_HINT` (obsolete). [notes §3](./99-notes.md#3-desktops).
