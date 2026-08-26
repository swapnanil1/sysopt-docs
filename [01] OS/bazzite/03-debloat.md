# Step 3 — Remove what you don't need

## What this step is

Bazzite comes with a set of Flatpak apps (sandboxed desktop apps) chosen by the project. You cannot delete programs that are *built into the system image* — that part is read-only — but Flatpaks are yours to remove, and once removed they **stay** removed; updates do not bring them back.

## 1. See what is installed

```bash
flatpak list --app
```

The first column is the app name, the second the "ID" (like `org.kde.kcalc`) — that ID is what you use to remove it.

## 2. Remove what you don't want

Example — a video player, calculator, disk-usage viewer and two app-store helpers many people don't use:

```bash
flatpak uninstall -y org.kde.haruna org.kde.kcalc org.kde.filelight io.github.flattool.Warehouse it.mijorus.gearlever
```

Adjust the list to taste. **Keep** these: Firefox (or whichever browser you want), Flatseal (permissions manager), ProtonUp-Qt / ProtonPlus (Proton versions for Steam), and anything whose ID contains `VulkanLayer` (MangoHud, vkBasalt, OBSVkCapture — they make the overlays work inside Flatpak games).

Then remove leftovers and clean up:

```bash
flatpak uninstall --unused -y     # runtimes no app needs any more
ujust clean-system                # old container images, unused Flatpaks, old system copies
```

## 3. Stop Steam from starting at login (optional)

Bazzite starts Steam silently in the background at every login. If you'd rather start it yourself:

```bash
rm -f ~/.config/autostart/steam.desktop
```

## What to leave alone

- **Do not** try to remove system packages with `rpm-ostree override remove` (for example Steam or Lutris). Bazzite doesn't document it and removing Steam breaks the image's own start-up wiring.
- Things that look like bloat but cost nothing unless you turn them on: `bees`, `snapper`, `btrfs-assistant`, `input-remapper`, `waydroid` (its service is off), `distrobox`, `cockpit`, `tailscale` (off). Leave them.

Background: [notes §3](./99-notes.md#3-debloat).
