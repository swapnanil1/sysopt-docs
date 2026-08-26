# 2 — fstab

If you did [step 0](./00-before-first-boot.md) the root/home lines and `tune2fs` are already done — verify with `findmnt -t ext4 -o TARGET,OPTIONS` and skip to the games disk.

```bash
lsblk -f -o NAME,FSTYPE,SIZE,ROTA,UUID,MOUNTPOINTS
sudo cp /etc/fstab /etc/fstab.bak
sudoedit /etc/fstab
```

## Root on ext4 HDDs (manual partitioning: `/`, `/var/home`, `/boot`, `/boot/efi`)

Keep the UUIDs Anaconda wrote; change only the option strings. On ostree the initramfs mounts the real root with the options from this `/` line (dracut parses the root's fstab when no `rootflags=` karg is set — Anaconda sets none for ext4), so the same rules as Arch apply.

```
# SAFE
UUID=<efi>    /boot/efi  vfat  umask=0077,shortname=winnt                                   0 2
UUID=<boot>   /boot      ext4  defaults,noatime                                             1 2
UUID=<root>   /          ext4  defaults,noatime,errors=remount-ro                           1 1
UUID=<home>   /var/home  ext4  defaults,noatime,errors=remount-ro                           1 2
# FAST
UUID=<root>   /          ext4  defaults,noatime,lazytime,commit=60,errors=remount-ro                    1 1
UUID=<home>   /var/home  ext4  defaults,noatime,lazytime,commit=60,data=writeback,errors=remount-ro     1 2
# FAST+ (UPS only): append ,barrier=0
```

`data=writeback` for `/` is baked into the superblock, not written in fstab (ext4 cannot switch data mode on a remount):

```bash
sudo tune2fs -o journal_data_writeback /dev/<root-partition>     # works on the mounted root; live from the next boot
# alternative, same effect from the kernel line:  sudo rpm-ostree kargs --append-if-missing=rootflags=data=writeback
```

If `rpm-ostree kargs` already shows a `rootflags=` entry, that entry — not fstab — is what the initramfs uses for `/`: put `noatime,lazytime,commit=60` in it too (`sudo rpm-ostree kargs --editor`). `/var` is a bind mount inside `/` and inherits its options. btrfs root (SSD, installer default): [notes §1](./99-notes.md#2-fstab).

## Games HDD — ext4, mounted under `/var/mnt`

`/mnt` is a symlink to `/var/mnt` on ostree; use the real path. NTFS/exFAT are unsupported for games on Bazzite (Proton breaks, data corruption warning in the docs) — ext4 for HDDs, btrfs for SSDs.

```bash
sudo mkdir -p /var/mnt/Games
```

```
# SAFE
UUID=<uuid>  /var/mnt/Games  ext4  defaults,noatime,nofail,x-systemd.device-timeout=15,errors=remount-ro                                   0 2
# FAST
UUID=<uuid>  /var/mnt/Games  ext4  defaults,noatime,lazytime,commit=60,data=writeback,nofail,x-systemd.device-timeout=15,errors=remount-ro  0 2
```

```bash
sudo findmnt --verify --verbose
sudo systemctl daemon-reload && sudo mount -a
sudo chown "$USER:$USER" /var/mnt/Games      # after the first mount
```

Alternative with zero fstab editing: label the filesystem (`sudo e2label /dev/sdX1 Games`) and run `ujust automounting` — Bazzite mounts labelled internal btrfs/ext4 drives at `/run/media/system/<LABEL>` with sane options. Steam is an RPM here (not a Flatpak), so it sees either path without portal permissions; the Protontricks Flatpak is pre-granted `/var/mnt` and `/run/media`.

A broken fstab boots the *previous* deployment from GRUB (`ostree:1`) — [08-rollback](./09-rollback.md). Details: [notes §1](./99-notes.md#2-fstab).
