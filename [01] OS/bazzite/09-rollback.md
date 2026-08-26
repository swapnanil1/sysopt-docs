# Step 9 — Keep a known-good system (pin) and back up your files

## What this step is

Bazzite keeps two copies ("deployments") of the system: the one you are running (`ostree:0` in the boot menu) and the previous one (`ostree:1`). After each update the older copy is thrown away. **Pinning** a deployment tells Bazzite "never throw this one away", so you can always boot back to the system exactly as it is right now, even months later.

Rolling back switches only the **system image**. Your files, your `/etc` edits and your Flatpaks are shared by all deployments and are never touched — which also means a rollback does not undo a mistake in `fstab`; for that you edit the file (Step 0 shows how from a live USB).

Backing up your **files** is a separate job; a rollback does not protect them.

## 1. Pin the current system

Do this now that everything works:

```bash
rpm-ostree status          # the entry marked ● is the running one; it is "deployment 0"
sudo ostree admin pin 0    # pin it. Undo later with: sudo ostree admin pin -u 0
```

`rpm-ostree status` now shows `Pinned: yes` on that entry.

## 2. How to roll back, when you need it

Something broke after an update? Either:

- at boot, hold `Shift` (or press `Esc`) to show the GRUB menu and pick the **`ostree:1`** entry — one-time boot into the previous system; or
- from the terminal, make the previous one the default and reboot:

```bash
rpm-ostree rollback
systemctl reboot
```

To go back to any Bazzite version from the last 90 days, Bazzite has a helper:

```bash
brh list                            # shows available versions
brh rebase stable:<version>         # switch to one of them; reboot afterwards
```

## 3. Back up your files (pick one)

Bazzite's built-in snapshot feature (`ujust configure-snapshots`) needs a btrfs home partition; with the ext4 layout from this guide it does not apply. Use one of these instead:

```bash
flatpak install -y flathub org.gnome.World.PikaBackup      # graphical, backs up to an external drive, keeps versions
```

or the plain command (an external drive mounted at `/run/media/<you>/EXT`):

```bash
rsync -aHAX --delete ~/ /run/media/$USER/EXT/home/
```

Timeshift (from the Arch guide) does not apply to Bazzite.

Background: [notes §9](./99-notes.md#9-rollback).
