# Step 7 — Kernel arguments (boot-time switches)

## What this step is

Kernel arguments are settings the Linux kernel reads once, when the computer boots — for example "turn off security mitigations" or "never power-save USB". On normal distros you edit a boot file; **on Bazzite you never do that** (the boot files are rewritten by every update). Instead you run `rpm-ostree kargs`, which records the arguments so that *every* future update keeps them, and creates a new copy of the system with them — which is why a reboot follows.

Run **one** command containing all the switches you want. Each run creates a new system copy; three runs = three copies to reboot through.

## 1. Choose your line

**SAFE** — no security or stability cost:

```bash
sudo rpm-ostree kargs \
  --append-if-missing=zswap.enabled=0 \
  --append-if-missing=iommu=pt \
  --append-if-missing=usbcore.autosuspend=-1 \
  --append-if-missing=audit=0
```

**MAX** — everything the CPU can give; CPU security mitigations are off (any program on the machine — including a web page's JavaScript — could in theory read memory it shouldn't; on a Ryzen the speed gain is a few percent):

```bash
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

One line each: `zswap.enabled=0` = don't double-compress swap (Bazzite uses zram); `iommu=pt` / `amd_iommu=off` = less overhead for devices (`off` also means no GPU passthrough to virtual machines, ever); `usbcore.autosuspend=-1` = USB devices never doze (fixes crackling USB audio, laggy mouse wake-up); `audit=0` = no audit logging; `mitigations=off` = Spectre-class fixes off; `init_on_alloc=0`, `randomize_kstack_offset=off` = two small kernel hardening features off; `pcie_aspm.policy=performance` = PCIe links never power-save.

`--append-if-missing` means "add it, but don't add it twice" — safe to re-run.

The watchdog switch comes from `ujust configure-watchdog` (Step 6) and the GPU OverDrive switch from Step 4; you don't repeat them here.

**Do not add** these (seen in other guides): `split_lock_detect=off` (Intel-only), `scsi_mod.scan=async`, `amd_pstate=active`, `preempt=full` (already defaults), `ahci.mobile_lpm_policy=max_performance` (the kernel rejects this spelling), `processor.max_cstate=1`, `idle=poll` (make the CPU hotter, not faster), `amdgpu.dcdebugmask=0x10` (laptop panels only).

## 2. Reboot and check

```bash
systemctl reboot
```

Then, in a new terminal:

```bash
rpm-ostree kargs                                                                            # prints the active line — your switches should be in it
journalctl -b -k --no-pager | grep -iE "invalid for parameter|Unknown kernel command line"   # must print NOTHING; a line here = a typo the kernel rejected
```

To remove a switch later: `sudo rpm-ostree kargs --delete-if-present=mitigations=off`, reboot.

What each switch costs in detail: [Arch notes §7](../arch/99-notes.md#7-kernel--cmdline). Bazzite specifics: [notes §7](./99-notes.md#7-kargs).
