# 9 — Checks, Timeshift baseline, reboot

```bash
sudo findmnt --verify
sudo bootctl list
systemctl --failed
journalctl -p 3 -b
pacman -Qtdq && sudo pacman -Rns $(pacman -Qtdq)     # orphans, if the list looks right
sudo paccache -rk2

sudo pacman -S --needed timeshift          # pulls gtk3/vte3/xapp/cronie (no CLI-only package). Not grub-btrfs, not xorg-xhost.
```

btrfs root:

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

`--tags O` (on-demand, never auto-pruned) — not `D`. Later:

```bash
sudo timeshift --list
sudo timeshift --restore --skip-grub       # always --skip-grub on systemd-boot
paru -S timeshift-autosnap                 # optional: snapshot before every pacman upgrade
sudo reboot
```

Restore when it no longer boots (no live ISO ships timeshift), btrfs by hand:

```bash
mount -o subvolid=5 /dev/<root> /mnt; mv /mnt/@ /mnt/@_broken
btrfs subvolume snapshot /mnt/timeshift-btrfs/snapshots/<date>/@ /mnt/@; umount /mnt; reboot
# kernel on ESP newer than modules in @ → mount subvol=@ + /boot, arch-chroot, pacman -S linux-cachyos
```

rsync from a live ISO: `pacman -Sy timeshift` then `timeshift --restore --snapshot-device /dev/sdXN --target /dev/<root> --skip-grub`. Snapshots ≠ backups: `rsync -aHAX --delete ~/ /run/media/<user>/EXT/home/`. [notes §9](./99-notes.md#9-timeshift).
