# 10 — Apps

Priority: Flatpak (GUI) → Homebrew (CLI) → `rpm-ostree install` (last resort; each layer = slower updates, reboot).

```bash
# gaming (Steam, Lutris, MangoHud, gamescope, umu, ProtonUp-Qt/ProtonPlus are already there)
flatpak install -y flathub com.heroicgameslauncher.hgl io.github.ilya_zlobintsev.LACT
flatpak install -y flathub dev.vencord.Vesktop            # or com.discordapp.Discord
flatpak install -y flathub com.obsproject.Studio          # VkCapture plugin runtime is preinstalled
# desktop
flatpak install -y flathub org.keepassxc.KeePassXC org.qbittorrent.qBittorrent io.mpv.Mpv org.telegram.desktop com.spotify.Client org.localsend.localsend_app com.rustdesk.RustDesk
flatpak install -y flathub org.libreoffice.LibreOffice    # or org.onlyoffice.desktopeditors
# dev
flatpak install -y flathub dev.zed.Zed                    # VS Code is in the DX image; node/go/php/laravel: step 1
brew install rustup uv syncthing && brew services start syncthing
# layering, only if nothing else works (reboot after)
sudo rpm-ostree install noise-suppression-for-voice
```

Steam launch options (no `gamemoderun` — removed from Bazzite):

```
mangohud %command%
gamescope -W 1920 -H 1080 -r 144 -f --mangoapp -- %command%     # or manage per game with ScopeBuddy (scb)
PROTON_NO_NTSYNC=1 %command%                                     # opt-OUT; NTSync is default-on
```

Global FSR 4 / DLSS overrides: `ujust global-fsr4`, `ujust global-dlss`. Performance profile while gaming: KDE power applet → *Performance* (or `powerprofilesctl set performance`). Dead options (delete): `PROTON_USE_NTSYNC=1`, `PROTON_NO_ESYNC`, `DXVK_ASYNC=1`, `mesa_glthread=true`, `gamemoderun`. Flatpak apps and the games HDD: grant `/var/mnt/Games` in Flatseal if an app needs it. [notes §9](./99-notes.md#10-apps).
