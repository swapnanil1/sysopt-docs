# 7 — `linux-cachyos` on systemd-boot + kernel command line

Install first, boot it, **then** remove `linux` — never the other way round.

```bash
sudo pacman -S --needed linux-cachyos                  # or linux-cachyos-bore; headers only for DKMS
sudo ls -l /boot/vmlinuz-linux-cachyos /boot/initramfs-linux-cachyos.img
blkid -s PARTUUID -o value /dev/<root-partition>
sudo sed -n 's/^options //p' /boot/loader/entries/*.conf   # your current options, for reference
```

`/boot/loader/entries/linux-cachyos.conf`:

```
title    Arch Linux (linux-cachyos)
linux    /vmlinuz-linux-cachyos
initrd   /initramfs-linux-cachyos.img
options  root=PARTUUID=<root-partuuid> rw rootfstype=ext4 <cmdline below>
```

No `initrd /amd-ucode.img` line needed (the `microcode` mkinitcpio hook embeds it). btrfs: `rootfstype=btrfs rootflags=subvol=@`.

`/boot/loader/loader.conf`:

```
default       linux-cachyos.conf
timeout       3
console-mode  max
editor        no          # FAST: yes
```

## Command line

```
# SAFE
nowatchdog audit=0 zswap.enabled=0 iommu=pt usbcore.autosuspend=-1 quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=auto
# MAX
mitigations=off init_on_alloc=0 randomize_kstack_offset=off nowatchdog audit=0 amd_iommu=off zswap.enabled=0 usbcore.autosuspend=-1 pcie_aspm.policy=performance quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=auto
```

Add `amdgpu.ppfeaturemask=0xfff7ffff` only for LACT fan curves/OC (value from step 4). Plain Arch without cachyos-settings: add `ahci.mobile_lpm_policy=1`.

Remove if you have them — rejected or no-ops: `ahci.mobile_lpm_policy=max_performance` (kernel rejects it; integer param), `split_lock_detect=off` (Intel only), `scsi_mod.scan=async`, `amd_pstate=active`, `preempt=full`, `transparent_hugepage=always`, `nmi_watchdog=0`, `nosoftlockup`, `spectre_v2=off`, `amdgpu.dcdebugmask=0x10`, `processor.max_cstate=1`, `idle=poll`. Per-parameter table: [notes §7](./99-notes.md#7-kernel--cmdline).

## Reboot, verify, remove the old kernel

```bash
sudo bootctl list && sudo reboot
uname -r
journalctl -b -k --no-pager | grep -iE "invalid for parameter|Unknown kernel command line"   # must be empty
kerver
# FAST: single kernel            SAFE: keep `linux` + its entry as a fallback
sudo pacman -Rns linux && sudo rm /boot/loader/entries/<old-entry>.conf
```

Fallback initramfs (SAFE, none exists by default): in `/etc/mkinitcpio.d/linux-cachyos.preset` set `PRESETS=('default' 'fallback')`, uncomment the `fallback_*` lines, `sudo mkinitcpio -P`, add an entry for `/initramfs-linux-cachyos-fallback.img`.
