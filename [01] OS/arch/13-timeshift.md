# 13 — Reboot, checks and Timeshift baseline

Finish the applicable system setup in steps 1–12 before this baseline. Applications and games come in [step 14](./14-apps.md).

## Reboot and verify the configured OS

Save your work and reboot so the checks below confirm persistent settings:

```bash
sudo reboot
```

After logging in, run:

```bash
uname -r
sudo findmnt --verify
sudo bootctl list
systemctl --failed
journalctl -p 3 -b
swapon --show
```

Confirm the intended kernel is running and investigate failed services or boot errors before taking the snapshot. Zram should be active. If you completed step 10, `/swap/swapfile` must also appear at priority 10, below zram's 100. A `findmnt` warning identifying the swapfile as a regular file is expected; activation in `swapon` is the check that it works.

## Create the baseline

Review orphan packages before removing anything:

```bash
pacman -Qtdq
# Optional, only for packages you reviewed: sudo pacman -Rns <package-names>
sudo paccache -rk2

sudo pacman -S --needed timeshift          # pulls gtk3/vte3/xapp/cronie (no CLI-only package). Not grub-btrfs, not xorg-xhost.
```

btrfs root:

If using [SSD swap alongside zram](./10-ssd-swap.md), keep it in the separate `@swap` subvolume mounted at `/swap`, outside the snapshot set. Do not place an active swapfile directly in `@`; that prevents taking its snapshot.

```bash
sudo btrfs subvolume list /                # @ and @home at top level
findmnt -no SOURCE,OPTIONS / /home         # subvol=/@ … no subvolid=
sudo timeshift --create --btrfs --comments "fresh install baseline" --tags O
```

ext4 root (rsync; destination = a separate Linux-fs partition, always passed explicitly):

```bash
sudo timeshift --list-devices
sudo timeshift --create --rsync --snapshot-device /dev/sdXN --comments "fresh install baseline" --tags O
```

`--tags O` (on-demand, never auto-pruned) — not `D`. Verify the snapshot exists, and optionally enable snapshots before package upgrades:

```bash
sudo timeshift --list
paru -S timeshift-autosnap                 # optional: snapshot before every pacman upgrade
```

Continue to [step 14 — applications and gaming](./14-apps.md). The recovery commands below are for a future rollback, not part of installation.

## Recovery: only when restoring a snapshot

From a running system:

```bash
sudo timeshift --restore --skip-grub       # always --skip-grub on systemd-boot
sudo reboot
```

Restore when it no longer boots (the Arch live ISO does not include Timeshift), btrfs by hand:

```bash
mount -o subvolid=5 /dev/<root> /mnt; mv /mnt/@ /mnt/@_broken
btrfs subvolume snapshot /mnt/timeshift-btrfs/snapshots/<date>/@ /mnt/@; umount /mnt; reboot
# kernel on ESP newer than modules in @ → mount subvol=@ + /boot, arch-chroot, pacman -S linux-cachyos
```

rsync from a live ISO: `pacman -Sy timeshift` then `timeshift --restore --snapshot-device /dev/sdXN --target /dev/<root> --skip-grub`. Snapshots ≠ backups: `rsync -aHAX --delete ~/ /run/media/<user>/EXT/home/`. [notes §13](./99-notes.md#13-timeshift).
