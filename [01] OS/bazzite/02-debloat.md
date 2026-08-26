# 2 — Debloat

Removing Flatpaks sticks (the image's flatpak manager does not reinstall them). Do **not** `rpm-ostree override remove` image RPMs — undocumented on Bazzite, and Steam/Lutris removal breaks the image's own wiring.

```bash
flatpak list --app                                            # see what the ISO installed
flatpak uninstall -y org.kde.haruna org.kde.kcalc org.kde.filelight io.github.flattool.Warehouse it.mijorus.gearlever   # examples — keep Firefox, Flatseal, ProtonUp-Qt/ProtonPlus, the MangoHud/vkBasalt/OBSVkCapture runtime layers
flatpak uninstall --unused -y
ujust clean-system                                            # podman prune + unused flatpaks + rpm-ostree cleanup
```

Steam autostarts silently at login; to stop it:

```bash
rm -f ~/.config/autostart/steam.desktop
```

Things that look like bloat but aren't: `bees`, `snapper`, `btrfs-assistant`, `input-remapper`, `waydroid` (service disabled), `distrobox`, `cockpit-*`, `tailscale` (disabled). They cost nothing at runtime unless enabled. [notes §2](./99-notes.md#2-debloat).
