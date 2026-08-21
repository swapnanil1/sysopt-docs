# 10 — Applications & gaming (after the snapshot)

```bash
# Steam / Proton
sudo pacman -S --needed lib32-vulkan-radeon ttf-liberation steam
sudo pacman -S --needed proton-cachyos-slr                      # per-game; keep Valve Proton as global default
sudo pacman -S --needed protonplus                              # GE-Proton fetcher (GTK) — KDE: protonup-qt ([cachyos], not AUR)
sudo pacman -S --needed mangohud lib32-mangohud gamescope lib32-gamescope
sudo pacman -S --needed umu-launcher lutris heroic-games-launcher-bin protontricks
sudo pacman -S --asdeps --needed wine-mono wine-gecko           # wine got pulled by protontricks; no lib32 tiers needed (new-WoW64)

# browsers / dev
sudo pacman -S --needed firefox                                 # chromium | brave-bin | zen-browser-bin | vivaldi
sudo pacman -S --needed code && paru -S code-marketplace code-features    # or: paru -S visual-studio-code-bin
sudo pacman -S --needed zed neovim intellij-idea-community-edition nodejs npm uv go rustup && rustup default stable
sudo pacman -S --needed docker docker-compose && sudo systemctl enable --now docker.socket && sudo usermod -aG docker "$USER"

# media / comms / utils
sudo pacman -S --needed mpv obs-studio spotify-launcher telegram-desktop vesktop keepassxc qbittorrent syncthing localsend fastfetch btop nvtop
sudo pacman -S --needed coolercontrol && sudo systemctl enable --now coolercontrold      # [cachyos], not the AUR -bin
paru -S rustdesk-bin
sudo pacman -S --needed android-tools android-file-transfer && sudo usermod -aG adbusers "$USER"
sudo pacman -S --needed libreoffice-fresh                       # or onlyoffice-bin ([cachyos])

# AMD compute / AI (optional)
sudo pacman -S --needed rocm-hip-runtime rocm-smi-lib ollama-vulkan whisper-cpp
paru -S lm-studio-bin
```

Skip: gamemode, bottles, bleachbit, xf86-video-*, steam-native-runtime.

`~/.config/MangoHud/MangoHud.conf`:

```
fps
frametime
frame_timing=1
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
vram
position=top-left
toggle_hud=Shift_L+F2
background_alpha=0.2
font_size=20
```

`~/.config/environment.d/gaming.conf`: `MESA_SHADER_CACHE_MAX_SIZE=12G`

Steam launch options (one `%command%`):

```
game-performance mangohud %command%
gamescope -W 1920 -H 1080 -r 144 -f --mangoapp -- %command%
PROTON_FSR4_UPGRADE=1 %command%            # GE / CachyOS Proton
PROTON_NO_NTSYNC=1 %command%               # opt-OUT; NTSync is default-on
PROTON_LOG=1 / DXVK_HUD=fps,frametimes,compiler / MESA_VK_WSI_PRESENT_MODE=immediate
```

Dead — delete from your launch options: `PROTON_USE_NTSYNC=1`, `PROTON_NO_ESYNC`, `DXVK_ASYNC=1`, `mesa_glthread=true`, `RADV_PERFTEST=…`, `PROTON_USE_EAC_LINUX`, `FSR4_UPGRADE=1`. Lutris/Heroic: wrapper command `game-performance`, Wine version `proton-cachyos-slr`. [notes §10](./99-notes.md#10-apps--gaming).
