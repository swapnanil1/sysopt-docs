# 1 — fstab

```bash
lsblk -f -o NAME,FSTYPE,SIZE,ROTA,UUID,MOUNTPOINTS
sudo cp /etc/fstab /etc/fstab.bak
sudoedit /etc/fstab
```

## Root btrfs on a HDD (installer layout: `root`, `var`, `home` subvolumes)

Keep the UUIDs and `subvol=` names the installer wrote; only change the option strings. All three lines must carry the **same** compression/commit options (btrfs applies the first-mounted subvolume's to the whole filesystem).

```
# SAFE  (installer line + noatime; zstd:3 on a HDD — fewer bytes for the slow disk)
UUID=<btrfs>  /          btrfs  subvol=root,compress=zstd:3,noatime                       0 0
UUID=<btrfs>  /var       btrfs  subvol=var,compress=zstd:3,noatime                        0 0
UUID=<btrfs>  /var/home  btrfs  subvol=home,compress=zstd:3,noatime                       0 0
# FAST
UUID=<btrfs>  /          btrfs  subvol=root,compress=zstd:3,noatime,lazytime,commit=120   0 0
UUID=<btrfs>  /var       btrfs  subvol=var,compress=zstd:3,noatime,lazytime,commit=120    0 0
UUID=<btrfs>  /var/home  btrfs  subvol=home,compress=zstd:3,noatime,lazytime,commit=120   0 0
```

No `data=writeback`/`tune2fs` step here: the root is btrfs (that is an ext4 journal option); it only applies to the ext4 games disk below, where fstab is enough. SSD root: keep the installer's `zstd:1`. Leave `/boot` (ext4) and `/boot/efi` (vfat) lines alone. Never `subvolid=`, never `nodatacow`/`autodefrag` (snapper), no `ssd`/`space_cache=v2`/`discard=async` (defaults).

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

A broken fstab boots the *previous* deployment from GRUB (`ostree:1`) — [08-rollback](./08-rollback.md). Details: [notes §1](./99-notes.md#1-fstab).
