# 0 — Before the first boot (installer still open)

Everything here is done from the installer's own shell after Anaconda says "Complete!" and **before** you click Reboot — the installed system is still mounted. Nothing needs a chroot: fstab is a file on the target, `tune2fs` works on the block device.

```bash
# Ctrl+Alt+F2 → root shell (tty2). Ctrl+Alt+F6 returns to the installer.
lsblk -f -o NAME,FSTYPE,LABEL,UUID,MOUNTPOINTS          # find the root partition (ext4, mounted under /mnt/…)
findmnt -R /mnt                                          # Anaconda mounts the physical root and the ostree deployment under /mnt/sysimage and /mnt/sysroot
T=$(ls -d /mnt/sysroot/etc /mnt/sysimage/etc 2>/dev/null | head -1 | xargs dirname)   # the tree that contains etc/fstab with real entries
grep -v '^#' "$T/etc/fstab"
```

## fstab — write the step-1 lines now

```bash
cp "$T/etc/fstab" "$T/etc/fstab.bak"
nano "$T/etc/fstab"        # /, /var/home, /boot, /boot/efi from 01-fstab.md; games disk line too (mkdir "$T/var/mnt/Games" is fine, /var is the persistent one)
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

## Later, from any live USB (system already installed)

The deployment is a directory on the root partition, not the root itself:

```bash
mount /dev/<root-partition> /mnt
D=$(ls -d /mnt/ostree/deploy/default/deploy/*.0 | head -1)     # current deployment; its /etc is $D/etc
nano "$D/etc/fstab"
tune2fs -o journal_data_writeback /dev/<root-partition>
umount /mnt
```

`chroot "$D"` is possible (`mount --bind /mnt/ostree/deploy/default/var "$D/var"` first) but unnecessary for these two edits, and `rpm-ostree` does not run inside such a chroot — kargs are always set from the booted system ([06-kargs](./06-kargs.md)). [notes §0](./99-notes.md#0-before-first-boot).
