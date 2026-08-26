# Step 10 — Applications and gaming

## What this step is

How to add programs on Bazzite, in the order the project recommends:

1. **Flatpak** for graphical apps (from the Bazaar app store or the terminal). They live outside the system image and survive updates.
2. **Homebrew** (`brew`) for command-line tools. Same.
3. **`rpm-ostree install`** ("layering") only if neither of the above can do it — every layered package is re-applied on each update and can block one, so keep the list short.

Already there, nothing to install: Steam, Lutris, MangoHud, gamescope, `umu`, ProtonUp-Qt / ProtonPlus, VS Code (DX), Docker (DX).

## 1. Install apps

```bash
# gaming
flatpak install -y flathub com.heroicgameslauncher.hgl                 # Epic / GOG / Amazon games
flatpak install -y flathub dev.vencord.Vesktop                         # Discord with working screen share on Wayland (or com.discordapp.Discord)
flatpak install -y flathub com.obsproject.Studio                       # recording/streaming; the game-capture plugin is preinstalled
# everyday
flatpak install -y flathub org.keepassxc.KeePassXC org.qbittorrent.qBittorrent io.mpv.Mpv org.telegram.desktop com.spotify.Client org.localsend.localsend_app com.rustdesk.RustDesk
flatpak install -y flathub org.libreoffice.LibreOffice                 # or org.onlyoffice.desktopeditors
# dev (VS Code is already in DX; node/php/laravel/go were installed in Step 2)
flatpak install -y flathub dev.zed.Zed
brew install rustup uv syncthing && brew services start syncthing
# layering — only if nothing else works; reboot afterwards
sudo rpm-ostree install noise-suppression-for-voice
```

If a Flatpak app needs to see the games disk, open **Flatseal**, pick the app, and add `/var/mnt/Games` under Filesystem.

## 2. Steam launch options

Right-click a game → Properties → Launch Options. Exactly one `%command%` per line.

```
mangohud %command%                                                # FPS / temperature overlay
gamescope -W 1920 -H 1080 -r 144 -f --mangoapp -- %command%      # run inside gamescope (fixed resolution, fps cap, upscaling); or use ScopeBuddy (scb) per game
PROTON_NO_NTSYNC=1 %command%                                      # only if a game misbehaves; NTSync is already on by default
```

Before a heavy game: KDE power icon → **Performance** (Step 6). Do **not** use `gamemoderun` — it is removed from Bazzite. Delete these if you see them in old guides: `PROTON_USE_NTSYNC=1`, `PROTON_NO_ESYNC`, `DXVK_ASYNC=1`, `mesa_glthread=true`.

FSR 4 / DLSS upgrades for all games at once: `ujust global-fsr4`, `ujust global-dlss`.

Background: [notes §10](./99-notes.md#10-apps).
