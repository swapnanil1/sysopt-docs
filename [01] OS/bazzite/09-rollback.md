# 9 — Rollback & backup

**What this does.** Pinning tells Bazzite "never delete this deployment" — otherwise the working OS you just finished tuning is gone two updates later. Rollback boots the previous deployment; it changes only the OS image, never your files (see the primer in the index). Home backup is separate: rollback does not protect your data, only the system.

Once everything works:

```bash
rpm-ostree status                   # deployment 0 = booted
sudo ostree admin pin 0             # this deployment is never garbage-collected; `pin -u 0` to unpin
```

Roll back the OS (your files under `/etc` and `/var` are untouched):

```bash
rpm-ostree rollback && systemctl reboot        # or pick "ostree:1" in GRUB (hold Esc/Shift at boot)
brh list && brh rebase stable:<version>        # any build from the last 90 days
```

Home backup (choose one; `ujust configure-snapshots`/snapper needs a btrfs home and does not apply to the ext4 layout):

```bash
flatpak install -y flathub org.gnome.World.PikaBackup    # borg-based, to an external drive
rsync -aHAX --delete ~/ /run/media/$USER/EXT/home/       # the plain version
```

Timeshift does not apply to ostree systems. [notes §8](./99-notes.md#9-rollback).
