# 8 — Rollback & backup

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

Timeshift does not apply to ostree systems. [notes §8](./99-notes.md#8-rollback).
