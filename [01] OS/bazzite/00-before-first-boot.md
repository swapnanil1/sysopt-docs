# Step 0 — Before the first boot (while the installer is still open)

## What this step is

The Bazzite installer has just finished copying the system to your disk, but you have **not rebooted yet**. At this exact moment the new system is sitting on the disk like a folder that is still open. We use that moment to do two small things that are safest to do *before* the first boot.

**Only two things happen in this step:**

1. Add the line for the **games hard drive** to the disk table (`fstab`).
2. Run one command (`tune2fs`) on the **system partition** that makes it a bit faster (this is the `data=writeback` setting from the Arch guide — it has to be written into the partition itself, not into a file).

Everything else — including the settings for the system partition's own line in `fstab` — is done **after** the first boot, in Step 1, where a mistake shows an error message instead of a computer that won't start.

> **Confused about "fstab before or after boot?" — here is the rule, once and for all:**
> - **Step 0 (now, installer still open):** games-disk line + `tune2fs`. Neither can stop the computer from booting.
> - **Step 1 (after the first boot):** the lines for `/` and `/var/home`. Same file, done on a running system where you can test it.
> - You may also do everything in Step 1 if you want (you just reboot one extra time). Both are fine.

## Before you start: two things to know

- **Placeholders.** Anything written like `<root-partition>` is something *you* replace with your own value (for example `/dev/sda3`). Never type the `<` `>` characters.
- **The root shell.** The installer has a hidden text console. `Ctrl+Alt+F2` switches to it (a black screen with a `#` prompt — you are already the administrator there, so no `sudo` is needed). `Ctrl+Alt+F6` switches back to the graphical installer.

## 1. Open the console and find your partitions

Wait until the installer says **"Complete!"**. Do **not** click Reboot yet. Press `Ctrl+Alt+F2`.

```bash
lsblk -f -o NAME,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

This prints every disk and partition. You will see something like:

```
NAME   FSTYPE LABEL UUID                                 MOUNTPOINTS
sda
├─sda1 vfat         1A2B-3C4D                            /mnt/sysimage/boot/efi
├─sda2 ext4         11111111-1111-1111-1111-111111111111 /mnt/sysimage/boot
├─sda3 ext4         22222222-2222-2222-2222-222222222222 /mnt/sysimage
└─sda4 ext4         33333333-3333-3333-3333-333333333333 /mnt/sysimage/var/home
sdb
└─sdb1 ext4         44444444-4444-4444-4444-444444444444
```

Write down:
- the **root partition** — the ext4 one mounted at `/mnt/sysimage` (or `/mnt/sysroot`); here `sda3`;
- the **games partition** — the one on the second disk with no mount point; here `sdb1`, and its long **UUID**.

(If you have not formatted the games disk yet: `mkfs.ext4 -L Games /dev/<games-partition>` — this **erases** that partition; double-check the name.)

## 2. Find the new system's `fstab` file

The installer mounts the new system under `/mnt/sysimage` or `/mnt/sysroot` (both names exist on Bazzite installers, one is the real system folder). This finds the right one for you and stores it in `T`:

```bash
T=$(ls -d /mnt/sysroot/etc /mnt/sysimage/etc 2>/dev/null | head -1 | xargs dirname)
echo "$T"                      # prints /mnt/sysroot or /mnt/sysimage — if it prints nothing, stop and ask
grep -v '^#' "$T/etc/fstab"    # shows the disk table the installer wrote (lines starting with # are comments)
```

## 3. Add the games-disk line

First make a backup copy, then open the file in the text editor `nano`:

```bash
cp "$T/etc/fstab" "$T/etc/fstab.bak"
mkdir -p "$T/var/mnt/Games"          # the folder the games disk will appear in
nano "$T/etc/fstab"
```

Use the arrow keys to go to the **end** of the file and type this **one** line (choose SAFE or FAST, not both), replacing `<games-uuid>` with the UUID you wrote down:

```
UUID=<games-uuid>  /var/mnt/Games  ext4  defaults,noatime,nofail,x-systemd.device-timeout=15,errors=remount-ro                                   0 2
```

FAST version of the same line (faster writes, a crash can lose the last minute of downloads — fine for a games disk):

```
UUID=<games-uuid>  /var/mnt/Games  ext4  defaults,noatime,lazytime,commit=60,data=writeback,nofail,x-systemd.device-timeout=15,errors=remount-ro  0 2
```

Do **not** touch the other lines in this step. Save and leave nano: `Ctrl+O`, `Enter`, then `Ctrl+X`.

Now check the file for mistakes:

```bash
findmnt --verify --tab-file "$T/etc/fstab"
```

You want to see **`Success, no errors or warnings detected`**. If it complains, open the file again and compare your line with the one above character by character (a very common mistake is a wrong UUID).

Why this line cannot break the boot: `nofail` means "if this disk is missing or the line is wrong, just skip it and keep booting".

## 4. Make the system partition faster (`tune2fs`)

This writes one setting into the root partition itself. It is safe to run now and takes effect from the very first boot. Replace `<root-partition>` with yours (for example `/dev/sda3` — the whole partition name, not the disk):

```bash
tune2fs -o journal_data_writeback /dev/<root-partition>
tune2fs -l /dev/<root-partition> | grep 'Default mount options'
```

The second command should print a line containing **`journal_data_writeback`**. That's it — you never need to run this again.

## 5. Go back and reboot

Press `Ctrl+Alt+F6` to return to the installer, click **Reboot**, remove the USB stick when asked. Continue with [Step 1](./01-fstab.md) once you are logged in to the desktop.

## If you skipped this step or the computer will not boot later

You can reach the same `fstab` file from any Linux live USB. The trick on Bazzite is that the system's files are inside a sub-folder of the root partition, not at the top:

```bash
mount /dev/<root-partition> /mnt
nano /mnt/ostree/deploy/default/deploy/*.0/etc/fstab     # fix the bad line, or remove it
umount /mnt
```

Then reboot. More background: [notes §0](./99-notes.md#0-before-first-boot).
