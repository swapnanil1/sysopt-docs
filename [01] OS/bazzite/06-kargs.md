# 6 — Kernel args

Bazzite bakes none; `rpm-ostree kargs` is the persistence mechanism (bootc has no karg command; the two interoperate). Never edit `/boot/loader/entries` by hand. One command, then reboot:

```bash
# SAFE
sudo rpm-ostree kargs \
  --append-if-missing=zswap.enabled=0 \
  --append-if-missing=iommu=pt \
  --append-if-missing=usbcore.autosuspend=-1 \
  --append-if-missing=audit=0

# MAX
sudo rpm-ostree kargs \
  --append-if-missing=mitigations=off \
  --append-if-missing=init_on_alloc=0 \
  --append-if-missing=randomize_kstack_offset=off \
  --append-if-missing=amd_iommu=off \
  --append-if-missing=zswap.enabled=0 \
  --append-if-missing=usbcore.autosuspend=-1 \
  --append-if-missing=pcie_aspm.policy=performance \
  --append-if-missing=audit=0
```

`nowatchdog` comes from `ujust configure-watchdog` (step 5); `amdgpu.ppfeaturemask` from step 3. Do not add: `split_lock_detect=off` (Intel only; the sysctl is already 0), `scsi_mod.scan=async`, `amd_pstate=active`, `preempt=full`, `ahci.mobile_lpm_policy=max_performance` (rejected — integer param; `=1` if you want it), `processor.max_cstate=1`, `idle=poll`, `amdgpu.dcdebugmask=0x10`.

```bash
sudo systemctl reboot
rpm-ostree kargs
journalctl -b -k --no-pager | grep -iE "invalid for parameter|Unknown kernel command line"   # must be empty
# remove one:  sudo rpm-ostree kargs --delete-if-present=mitigations=off
```

Meaning and cost of each: [Arch notes §7](../arch/99-notes.md#7-kernel--cmdline); Bazzite specifics: [notes §6](./99-notes.md#6-kargs).
