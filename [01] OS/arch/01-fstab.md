# 1 — fstab

```bash
lsblk -f -o NAME,FSTYPE,SIZE,ROTA,UUID,MOUNTPOINTS    # ROTA=1 HDD, 0 SSD
sudo cp /etc/fstab /etc/fstab.bak
sudoedit /etc/fstab
```

Rules: `UUID=` only · `dump` 0 · `pass` 1 for ext4 `/`, 2 for other ext4/vfat, **0 for every btrfs line** · `noatime` everywhere · `errors=remount-ro` on every ext4 line (Arch's mkfs default is `continue`). Never write: `nobh`, `delalloc`, `auto_da_alloc`, `dioread_nolock`, `journal_checksum`, `data=ordered`, `barrier=1`, `discard`, btrfs `ssd`/`space_cache=v2`/`discard=async`, `comment=x-gvfs-show`, `user` (implies `noexec`). Details: [notes §1](./99-notes.md#1-fstab).

## OS drive — ext4 (HDD or SSD, same lines)

```
# SAFE
UUID=<esp>    /boot  vfat  defaults,noatime,fmask=0077,dmask=0077   0 2
UUID=<root>   /      ext4  defaults,noatime,errors=remount-ro       0 1
UUID=<home>   /home  ext4  defaults,noatime,errors=remount-ro       0 2
# FAST
UUID=<root>   /      ext4  defaults,noatime,lazytime,commit=60,errors=remount-ro                  0 1
UUID=<home>   /home  ext4  defaults,noatime,lazytime,commit=60,data=writeback,errors=remount-ro   0 2
# FAST+ (UPS only): append ,barrier=0
```

`data=writeback` on `/` cannot come from fstab — bake it in once: `sudo tune2fs -o journal_data_writeback /dev/<root-partition>` (or `rootflags=data=writeback` on the cmdline, step 7).

## OS drive — btrfs (`@` / `@home`, Timeshift-compatible)

```
# SAFE (HDD: keep zstd:3 in FAST too)
UUID=<btrfs>  /      btrfs  defaults,noatime,compress=zstd:3,subvol=@       0 0
UUID=<btrfs>  /home  btrfs  defaults,noatime,compress=zstd:3,subvol=@home   0 0
# FAST (SSD)
UUID=<btrfs>  /      btrfs  defaults,noatime,lazytime,compress=zstd:1,commit=120,subvol=@       0 0
UUID=<btrfs>  /home  btrfs  defaults,noatime,lazytime,compress=zstd:1,commit=120,subvol=@home   0 0
```

`subvol=@` never `subvolid=` · `@` and `@home` option strings identical · no `nodatacow`/`autodefrag` · cmdline needs `rootflags=subvol=@` (step 7). archinstall's extra subvolumes (`@log`, `@pkg`, …) keep their generated lines.

## Extra drives (one entry per disk)

```bash
sudo mkdir -p /mnt/Games && sudo chown "$USER:$USER" /mnt/Games   # chown again after the first mount
```

```
# ext4 HDD or SSD — SAFE
UUID=<uuid>  /mnt/Games  ext4   defaults,noatime,nofail,x-systemd.device-timeout=15,errors=remount-ro,x-gvfs-show                                   0 2
# ext4 — FAST
UUID=<uuid>  /mnt/Games  ext4   defaults,noatime,lazytime,commit=60,data=writeback,nofail,x-systemd.device-timeout=15,errors=remount-ro,x-gvfs-show  0 2
# btrfs — SAFE / FAST
UUID=<uuid>  /mnt/Data   btrfs  defaults,noatime,compress=zstd:3,nofail,x-systemd.device-timeout=15,x-gvfs-show                       0 0
UUID=<uuid>  /mnt/Data   btrfs  defaults,noatime,lazytime,compress=zstd:1,commit=120,nofail,x-systemd.device-timeout=15,x-gvfs-show   0 0
# NTFS (kernel ntfs3, no ntfs-3g)
UUID=<uuid>  /mnt/Win    ntfs3  defaults,noatime,uid=1000,gid=1000,umask=022,nofail,x-systemd.device-timeout=15   0 0
```

## Apply

```bash
sudo findmnt --verify --verbose      # must say no errors
sudo systemctl daemon-reload && sudo mount -a
sudo systemctl enable fstrim.timer   # TRIM weekly (we never use discard)
```

No swap line: zram comes with step 6. I/O schedulers come with step 6 too.
