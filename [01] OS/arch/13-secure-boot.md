# 13 — Unified kernel image at install, then Secure Boot with your own keys

Two parts. **A and B** happen at install time and replace step 7's entry file: archinstall builds the kernel as one signed-able `.efi` file (a unified kernel image, UKI: kernel, initramfs and command line in one), and the swap to `linux-cachyos` keeps that shape. **C** is optional and can be done any time later: Secure Boot with your own keys, lockdown, TPM measured boot. Windows on the same disk keeps booting.

Why the UKI: Secure Boot checks the one file the firmware starts. Classic boot starts only the kernel and reads the initramfs and the command line unsigned from the disk. A UKI puts all three in the checked file. Without Secure Boot the UKI gains you nothing; it is here because part C needs it.

A kernel signed by your key is not a kernel signed by a distribution key. Software that insists on the latter will not accept it. Part C is for your own machine's security, not for that check.

---

## A. archinstall with a unified kernel image

In archinstall, same choices as the guide's start point, plus one:

- **Bootloader:** systemd-boot
- **Unified kernel images:** enabled
- Filesystem and the rest as in the index page. The ESP lands at `/boot`.

After the first boot, this is what the option produced:

```bash
cat /etc/kernel/cmdline                    # the command line now lives here
grep uki /etc/mkinitcpio.d/linux.preset    # default_uki="/boot/EFI/Linux/arch-linux.efi"
ls /boot/EFI/Linux/                        # arch-linux.efi (+ fallback)
ls /boot/loader/entries/                   # empty: systemd-boot lists the .efi files itself
```

Then step 1 (fstab) and step 2 (CachyOS repos) as usual. Skip to part B instead of step 7.

---

## B. linux-cachyos, keeping the UKI (replaces step 7's entry file)

The UKI settings are per kernel and live in the kernel's preset. The new package brings its own preset in classic form, so copy the UKI one over it and rename three paths:

```bash
sudo pacman -S --needed linux-cachyos
sudo cp /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux-cachyos.preset
sudo sed -i 's/vmlinuz-linux"/vmlinuz-linux-cachyos"/; s/arch-linux\.efi/arch-linux-cachyos.efi/; s/arch-linux-fallback\.efi/arch-linux-cachyos-fallback.efi/' /etc/mkinitcpio.d/linux-cachyos.preset
cat /etc/mkinitcpio.d/linux-cachyos.preset   # ALL_kver and both _uki lines say cachyos
```

Command line: keep `root=...` as archinstall wrote it, append the step 7 line of your choice, and `lockdown=integrity` if part C is coming. One file serves every kernel:

`/etc/kernel/cmdline`:

```
root=PARTUUID=<root-partuuid> rw rootfstype=ext4 nowatchdog audit=0 zswap.enabled=0 iommu=pt usbcore.autosuspend=-1 quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=auto lockdown=integrity
```

btrfs: `rootfstype=btrfs rootflags=subvol=@`. Keep `iommu=pt`, not `amd_iommu=off`: part C relies on the IOMMU.

```bash
sudo mkinitcpio -P
ls /boot/EFI/Linux/                          # arch-linux.efi and arch-linux-cachyos.efi
```

`/boot/loader/loader.conf`:

```
default       arch-linux-cachyos.efi
timeout       3
console-mode  max
editor        no
```

`editor no` stops anyone at the keyboard from booting the kernel with `init=/bin/sh`. Not optional once the image is signed.

```bash
sudo bootctl list && sudo reboot
uname -r                                     # cachyos
cat /proc/cmdline                            # your file's line
sudo pacman -Rns linux                       # its UKI is removed with it
```

Changing the command line later: edit `/etc/kernel/cmdline`, `sudo mkinitcpio -P`. Nothing else.

**Installed the classic way already** (entry file from step 7)? Create the preset lines above by hand, `mkinitcpio -P`, delete the entry file, set `default` in loader.conf, reboot once with Secure Boot still off to confirm it starts.

---

## C. Secure Boot with your own keys

### C1. A way back

Keep a USB stick with the Arch ISO. With Secure Boot on it will not boot until Secure Boot is switched off in the firmware again, which is always possible from the firmware menu. Nothing here can lock you out of the firmware.

```bash
sudo pacman -S --needed sbctl
```

### C2. Firmware: Setup Mode and the TPM

Reboot into the firmware (Delete at power-on on the Gigabyte board):

- **Boot → Secure Boot:** *Secure Boot Mode* **Custom** → **Key Management** → **Reset To Setup Mode** (also called *Clear Secure Boot Keys* or *Delete PK*). Leave *Secure Boot* itself at Enabled; with no keys it does not enforce yet.
- **Settings → AMD CBS (or Miscellaneous) → AMD fTPM:** Enabled.
- **Boot → CSM Support:** Disabled.

Save, boot Linux:

```bash
sudo sbctl status            # Setup Mode: Enabled   Secure Boot: Disabled
ls /sys/class/tpm/           # tpm0
```

### C3. Keys, signatures, enrolment

```bash
sudo sbctl create-keys                                   # /var/lib/sbctl/keys, root only
sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign -s /boot/EFI/Linux/arch-linux-cachyos.efi
sudo sbctl sign -s /boot/EFI/Linux/arch-linux-cachyos-fallback.efi
sudo sbctl verify                                        # each "is signed"; Microsoft's own files excepted
```

`-s` records the file in sbctl's database so the pacman hook re-signs it after updates. Do not sign anything under `/boot/EFI/Microsoft`: the Windows boot manager carries Microsoft's signature already.

```bash
sudo sbctl enroll-keys -m
```

`-m` enrols Microsoft's certificates beside yours. Not optional on this machine: Windows boots through Microsoft's signature, and so does the graphics card's own firmware (its option ROM, the code that draws the screen before any driver loads). Without `-m` the firmware refuses the card at power-on, the screen stays black, and with no onboard graphics on a Ryzen 3600 there is no picture left to turn Secure Boot off with. sbctl stops with an option ROM warning in that case; the answer is `-m`, never the flag that skips the check.

Reboot. Setting the platform key ends Setup Mode and Secure Boot enforces from the next boot. If the firmware still shows it disabled, set *Secure Boot* to Enabled in the same menu once.

### C4. Lockdown and kexec

Secure Boot stops unsigned code before the kernel runs. Lockdown stops root from getting around it afterwards. The CachyOS kernel builds the lockdown module in but leaves it off and does not switch it on when it sees Secure Boot, so it has to be asked for: `lockdown=integrity` in the command line, part B.

In integrity mode root cannot load a module that is not signed with a key the kernel trusts, write to kernel memory through `/dev/mem`, change MSRs, or replace the running kernel through kexec with an unsigned image. Every module in the `linux-cachyos` package is signed at build time and loads as before. Modules built on the machine do not: `v4l2loopback`, VirtualBox, any DKMS package. If you need one, stop at part B.

kexec of a signed image is still allowed. Close that too:

```bash
echo 'kernel.kexec_load_disabled = 1' | sudo tee /etc/sysctl.d/99-lockdown.conf
```

### C5. Verify

```bash
sudo sbctl status                 # Secure Boot: Enabled   Setup Mode: Disabled   Vendor Keys: microsoft
sudo bootctl status | grep -iE "secure boot|measured|tpm2"
                                  # Secure Boot: enabled (user)   Measured UKI: yes   TPM2 Support: yes
cat /sys/kernel/security/lockdown # none [integrity] confidentiality
sysctl kernel.kexec_load_disabled # 1
```

Windows still shows in the boot menu and still boots. The Arch ISO on a stick does not, until Secure Boot is disabled in the firmware; expected.

### C6. Updates

sbctl's pacman hook and its mkinitcpio post hook sign the new UKI on every kernel update and re-sign systemd-boot when systemd updates. After the first kernel update:

```bash
sudo sbctl verify
```

Back up `/var/lib/sbctl` somewhere that is not this disk. It holds the private keys. Losing them means enrolling new ones from Setup Mode again, a five-minute firmware trip.

### C7. If it does not boot

- **Firmware says the image failed verification:** firmware → Secure Boot Disabled → boot Linux → `sudo sbctl verify` → sign what is unsigned → enable again.
- **Black screen at power-on right after enrolment:** keys went in without `-m`. Clear CMOS (jumper or battery), the firmware returns to Setup Mode with vendor keys, enrol again with `-m`.
- **A module refuses to load:** `journalctl -b -k | grep -i "module verification"`. Lockdown refusing an unsigned module. Remove the package or drop `lockdown=integrity`.
- **Remove all of it:** `sudo sbctl reset`, Secure Boot Disabled in the firmware. The UKI from part B keeps booting unsigned.
