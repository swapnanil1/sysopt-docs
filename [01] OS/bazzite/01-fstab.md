# Step 1 — fstab: the disk table (after the first boot)

## What this step is

`/etc/fstab` is a plain text file that lists every partition, where it appears in the folder tree, and the options it is mounted with. Changing the options is how we make the hard drives faster. This file lives in `/etc`, so Bazzite updates **never overwrite it** — you edit it once and it stays.

> **Where does fstab happen? Both, split by risk.**
> - **Step 0 (installer, before the first boot):** games-disk line + `tune2fs`. Done — if you did Step 0.
> - **Step 1 (now, after the first boot):** the lines for `/` (the system) and `/var/home` (your files). We do these on the running system because if you make a typo, a command tells you *now* instead of the computer failing to start next time.
> - Skipped Step 0? No problem — this step also tells you what to do for the games disk and `tune2fs`.

A mistake in this file **can** stop the computer from booting. That is why you will make a backup first and run a checking command before you reboot. If it does go wrong anyway, [Step 9](./09-rollback.md) explains how to boot the previous copy of the system and fix the file.

## 1. Open a terminal

Konsole (KDE's terminal) from the application menu. Commands starting with `sudo` will ask for your password; nothing shows while you type it — that is normal.

## 2. Look at what you have

```bash
lsblk -f -o NAME,FSTYPE,SIZE,ROTA,UUID,MOUNTPOINTS
```

- `ROTA 1` = a spinning hard drive (HDD), `0` = SSD. This guide assumes both your drives show `1`.
- Note which partition is `/` (the system) and which is `/var/home` (your files).

Now look at the current disk table:

```bash
cat /etc/fstab
```

Each line has six columns: **what** (`UUID=…`), **where** (`/`, `/var/home`, …), **type** (`ext4`, `vfat`), **options** (the part we change), and two numbers at the end (leave them as they are). Lines starting with `#` are comments.

## 3. Back up the file and open it

```bash
sudo cp /etc/fstab /etc/fstab.bak
sudoedit /etc/fstab
```

`sudoedit` opens the file in `nano` with permission to save. In nano: arrow keys to move, `Ctrl+O` then `Enter` to save, `Ctrl+X` to leave.

## 4. Change the options of the `/` and `/var/home` lines

Only edit the **options** column (4th column). Keep the `UUID=…` at the start of each line exactly as the installer wrote it — do not copy the placeholder `<root>` below.

**SAFE** — safe even if the power goes out:

```
UUID=<root>   /          ext4  defaults,noatime,errors=remount-ro                           1 1
UUID=<home>   /var/home  ext4  defaults,noatime,errors=remount-ro                           1 2
```

**FAST** — what this guide is for; a crash can lose the last minute of writes, the disk itself stays healthy:

```
UUID=<root>   /          ext4  defaults,noatime,lazytime,commit=60,errors=remount-ro                    1 1
UUID=<home>   /var/home  ext4  defaults,noatime,lazytime,commit=60,data=writeback,errors=remount-ro     1 2
```

What the words mean, in one line each: `noatime` = don't write a timestamp every time a file is *read* (big saving on an HDD); `lazytime` = keep timestamps in memory and write them later; `commit=60` = flush the journal every 60 s instead of 5; `data=writeback` = don't force file data to hit the disk before its bookkeeping; `errors=remount-ro` = if the filesystem is damaged, switch to read-only instead of making it worse.

Notice `data=writeback` is on the `/var/home` line but **not** on the `/` line. For `/` it does not work from this file (the system is mounted before the file is read) — that is what `tune2fs` in Step 0 was for. If you skipped Step 0, run it now; it takes effect at the next reboot:

```bash
sudo tune2fs -o journal_data_writeback /dev/<root-partition>       # e.g. /dev/sda3 — the partition, not the disk
```

Leave the `/boot` and `/boot/efi` lines alone (you may add `,noatime` to `/boot`'s options; nothing else).

Optional FAST+ for people with a UPS only: add `,barrier=0` to the `/` and `/var/home` options. Without a UPS a power cut can corrupt the filesystem — skip it.

## 5. The games disk (skip if you did Step 0)

`/mnt` on Bazzite is really `/var/mnt` — always use the full `/var/mnt/...` path. Games disks must be **ext4** (HDD) or **btrfs** (SSD); NTFS/exFAT are not supported for games on Bazzite and can corrupt data.

```bash
sudo mkdir -p /var/mnt/Games
```

Add **one** of these lines at the end of `/etc/fstab` (find the UUID in the `lsblk` output from step 2):

```
# SAFE
UUID=<games-uuid>  /var/mnt/Games  ext4  defaults,noatime,nofail,x-systemd.device-timeout=15,errors=remount-ro                                   0 2
# FAST
UUID=<games-uuid>  /var/mnt/Games  ext4  defaults,noatime,lazytime,commit=60,data=writeback,nofail,x-systemd.device-timeout=15,errors=remount-ro  0 2
```

`nofail` = "if this disk is missing, keep booting"; `x-systemd.device-timeout=15` = "wait at most 15 seconds for it".

## 6. Check, then apply — without rebooting

```bash
sudo findmnt --verify --verbose
```

You want **`Success, no errors or warnings detected`**. Any other message = fix the file before going on (`sudo cp /etc/fstab.bak /etc/fstab` restores the backup if you want to start over).

```bash
sudo systemctl daemon-reload      # tell the system the table changed
sudo mount -a                     # mount everything in the table now
findmnt -t ext4 -o TARGET,OPTIONS # shows each mount and the options actually in use
sudo chown "$USER:$USER" /var/mnt/Games     # make the games folder yours (run once, after it is mounted)
```

If `mount -a` prints an error, it names the line that is wrong. The `/` line's new options only fully apply after a reboot; the others apply immediately.

## Alternative for the games disk: no fstab editing at all

Bazzite can mount any internal drive that has a **label** automatically at `/run/media/system/<LABEL>`:

```bash
sudo e2label /dev/<games-partition> Games     # give it the label "Games"
ujust automounting                            # turn Bazzite's automount on
```

Steam is installed as a normal program (not a Flatpak), so it can use either location without extra permissions.

Background and the btrfs (SSD) variant: [notes §1](./99-notes.md#1-fstab).
