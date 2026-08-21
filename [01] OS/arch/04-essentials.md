# 4 — Essentials & hardware

```bash
# audio (pipewire/wireplumber/pipewire-pulse came with the DE)
sudo pacman -S --needed pipewire-alsa pipewire-jack alsa-utils
sudo pacman -S --needed rtkit                 # SAFE: realtime priority for audio threads via RTKit
# sudo gpasswd -a "$USER" audio               # FAST: cachyos-settings grants @audio rtprio 99 (re-login). Pick one; not realtime-privileges as well.

# AMD GPU (mesa is pulled by the compositor; RADV is not)
sudo pacman -S --needed vulkan-radeon lib32-mesa lib32-vulkan-radeon
sudo pacman -S --needed vulkan-tools mesa-utils libva-utils nvtop      # optional diagnostics
sudo pacman -S --needed lact && sudo systemctl enable --now lactd.service    # fan curve / power limit / monitoring (corectrl replacement)

# Bluetooth (bluez pulled by bluedevil / gnome-control-center / blueman)
sudo pacman -S --needed bluez-utils && sudo systemctl enable --now bluetooth.service

# fonts (noto-fonts came with the DE)
sudo pacman -S --needed noto-fonts-emoji ttf-liberation ttf-dejavu ttf-jetbrains-mono ttf-nerd-fonts-symbols-mono
# optional: noto-fonts-cjk (299 MiB) · paru -S ttf-ms-fonts

# storage & archives
sudo pacman -S --needed exfatprogs smartmontools 7zip unrar zip unzip
sudo pacman -S --needed hdparm                # HDD boxes: activates cachyos-settings' no-spindown rule (step 6)
# GNOME: sudo pacman -S --needed gvfs-mtp gvfs-smb     KDE: kio-extras already covers mtp:/ smb:/

# codecs — KDE: ffmpeg is already there (ffmpegthumbs in step 3). GNOME: gst-* in step 3. Never list x264/x265/lame.

# firewall — SAFE (FAST: skip entirely)
sudo pacman -S --needed ufw
sudo ufw default deny incoming && sudo ufw default allow outgoing && sudo ufw enable
# sudo ufw allow ssh

# resolv.conf → systemd-resolved stub (NetworkManager hands DNS to resolved once cachyos-settings is in)
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# flatpak (optional; Flathub remote is added by the package)
sudo pacman -S --needed flatpak
```

LACT fan curves on RDNA3/4 need OverDrive — add to the cmdline in step 7 (SAFE value = default mask | 0x4000):

```bash
printf 'amdgpu.ppfeaturemask=0x%x\n' "$(( $(cat /sys/module/amdgpu/parameters/ppfeaturemask) | 0x4000 ))"
```

Don't enable: `cronie`, `acpid`, `avahi-daemon`. Groups: `wheel` only (plus `audio` if you took the FAST audio path). Don't install: `xf86-video-amdgpu`, `ntfs-3g`, `exfat-utils`, `p7zip`, `amdvlk`, `realtime-privileges`, `reflector`. [notes §4](./99-notes.md#4-essentials--hardware).
