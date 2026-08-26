# 0 — Before the first boot (installer still open)

**What this does.** The installer has already written Bazzite to the disk; it just hasn't been booted yet. Because the installed system is still mounted, you can open a terminal *inside the installer* and edit its files directly — no "immutable" tricks needed.

> **Where does fstab happen? Both, split by risk.**
> - **Step 0 (installer shell, before the first boot):** only the games-disk line and `tune2fs` on the root partition. Neither can stop the system from booting.
> - **Step 1 (after the first boot):** the `/` and `/var/home` option lines. Same file — done on a running system so `mount -a` shows a mistake immediately instead of a failed first boot.
> - Prefer one place? Everything in step 0 (risk: a root-line typo = live-USB fix) or everything in step 1 (cost: one extra reboot for `tune2fs`). Both are fine.

Everything here is done from the installer's own shell after Anaconda says "Complete!" and **before** you click Reboot — the installed system is still mounted. Nothing needs a chroot: fstab is a file on the target, `tune2fs` works on the block device.

```bash
# Ctrl+Alt+F2 → root shell (tty2). Ctrl+Alt+F6 returns to the installer.
lsblk -f -o NAME,FSTYPE,LABEL,UUID,MOUNTPOINTS          # find the root partition (ext4, mounted under /mnt/…)
findmnt -R /mnt                                          # Anaconda mounts the physical root and the ostree deployment under /mnt/sysimage and /mnt/sysroot
T=$(ls -d /mnt/sysroot/etc /mnt/sysimage/etc 2>/dev/null | head -1 | xargs dirname)   # the tree that contains etc/fstab with real entries
grep -v '^#' "$T/etc/fstab"
```

## fstab — write the step-2 lines now

```bash
cp "$T/etc/fstab" "$T/etc/fstab.bak"
nano "$T/etc/fstab"        # append the games-disk line from 01-fstab.md (it has nofail); leave the installer's /, /var/home, /boot lines alone for now
findmnt --verify --tab-file "$T/etc/fstab"    # must report no errors (UUID checks work because the devices are present)
```

`/var/mnt/Games`: create it now (`mkdir -p "$T/var/mnt/Games"`) — on ostree `/var` is populated from the deployment at install time and persists, so it will exist on first boot.

## ext4 root: data=writeback baked into the superblock

```bash
tune2fs -o journal_data_writeback /dev/<root-partition>      # works mounted or not; effective from the first boot
tune2fs -l /dev/<root-partition> | grep 'Default mount options'   # journal_data_writeback listed
```

`/var/home` and the games disk take `data=writeback` in fstab directly — no tune2fs.

## Then

Ctrl+Alt+F6 → Reboot. Kernel args, udev, sysctl/tuned and everything else are post-boot steps (they need `rpm-ostree`/systemd running).

## Recovery only (skipped step 0, or fstab broke the boot)

From any live USB the deployment's `/etc` is a directory on the root partition, not `/mnt/etc`:

```bash
mount /dev/<root-partition> /mnt && nano /mnt/ostree/deploy/default/deploy/*.0/etc/fstab && umount /mnt
```

No chroot needed; kargs are still a post-boot job ([07-kargs](./07-kargs.md)). [notes §0](./99-notes.md#0-before-first-boot).
