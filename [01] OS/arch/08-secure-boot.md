# 8 — One-file kernel, then Secure Boot with your own keys

What this step gets you: the firmware refuses to start anything on this disk that you did not sign, and the running kernel refuses to let root undo that. Windows on the same disk keeps booting. Your files, logins and apps are untouched by any of it.

**UKI path from step 7:** complete part B to install and verify the kernel, then optionally part C for Secure Boot. Continue to [step 9 — sysctl](./09-sysctl.md) afterwards. If you completed the classic-entry path in step 7 and want to keep it, skip this page.

Three parts. **A** describes the UKI option already selected during installation; it is reference, not a request to reinstall. **B** swaps the stock kernel for `linux-cachyos` while retaining the UKI boot method. **C** turns Secure Boot on with your own keys and can be done now or later, or skipped.

One warning before you start. Your kernel will be signed by your key, not by Arch or Microsoft. Software that checks for a distribution's signature, some anti-cheat for example, will not treat it as "Secure Boot on". Part C protects your machine from tampering; it does not pass that kind of check.

## Words used here

| Word | Meaning |
|---|---|
| ESP | The small FAT partition the firmware reads at power-on. On this install it is mounted at `/boot`. |
| UKI | Unified kernel image. The kernel, the initramfs and the command line packed into one `.efi` file. Secure Boot can check one file, so everything that matters has to be in that one file. |
| Preset | A small text file in `/etc/mkinitcpio.d/` that tells mkinitcpio what to build for one kernel: a loose initramfs, or a UKI, and where to put it. One preset per installed kernel. |
| systemd-boot | The boot menu. It lives on the ESP and starts whichever `.efi` it finds in `EFI/Linux`. |
| Setup Mode | The firmware state where no owner key is enrolled yet. Secure Boot can be switched on but enforces nothing until a key goes in. |
| Platform key | Your owner key. Enrolling it ends Setup Mode and starts enforcement. |
| Option ROM | Firmware inside the graphics card that draws the screen before any driver loads. The firmware checks its signature too, and it is signed by Microsoft. |
| Lockdown | A kernel mode where root cannot load unsigned modules, poke kernel memory, or swap the running kernel. |
| Hook | A script that pacman or mkinitcpio runs by itself after a package or image changes. The signing after updates is done by hooks. |

---

## A. archinstall with a unified kernel image

Same choices as the guide's start page, plus one:

- **Bootloader:** systemd-boot
- **Unified kernel images:** enabled

After the first boot you have this, and it is worth looking at once so part B makes sense:

```bash
cat /etc/kernel/cmdline                    # the kernel command line now lives in this file
grep uki /etc/mkinitcpio.d/linux.preset    # default_uki="/boot/EFI/Linux/arch-linux.efi"
ls /boot/EFI/Linux/                        # arch-linux.efi
ls /boot/loader/entries/                   # empty: systemd-boot finds the .efi files on its own
```

For the post-install sequence, complete steps 1–6, read step 7's command-line section, then do part B below instead of creating a classic boot entry.

---

## B. Swap to `linux-cachyos`, keeping the UKI

Order matters: install the new kernel, boot it, confirm it, and only then remove the old one.

### B1. Install the kernel and fix its preset

```bash
sudo pacman -S --needed linux-cachyos
```

The install prints a mkinitcpio run that builds `/boot/initramfs-linux-cachyos.img`. That is the package's own preset at work, and it is the wrong kind: it builds a loose initramfs, which needs a boot entry file you do not have. Seeing `linux-cachyos.preset` already in `/etc/mkinitcpio.d/` does not mean this step is done. Replace it with a copy of the UKI preset archinstall made, then point the copy at the new kernel:

```bash
sudo cp /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux-cachyos.preset
sudo sed -i 's/vmlinuz-linux"/vmlinuz-linux-cachyos"/; s/arch-linux\.efi/arch-linux-cachyos.efi/; s/arch-linux-fallback\.efi/arch-linux-cachyos-fallback.efi/' /etc/mkinitcpio.d/linux-cachyos.preset
grep -vE '^\s*#|^\s*$' /etc/mkinitcpio.d/linux-cachyos.preset
```

Check: the output has `ALL_kver="/boot/vmlinuz-linux-cachyos"`, `default_uki="/boot/EFI/Linux/arch-linux-cachyos.efi"`, and no `default_image` line. The first comment line still says "for the 'linux' package"; comments do nothing, ignore it.

The two presets do not depend on each other. Removing the old kernel later takes `linux.preset` with it and the cachyos one keeps working.

### B2. The command line, once for every kernel

Open `/etc/kernel/cmdline`. Keep the `root=...` part exactly as archinstall wrote it and add the step 7 line of your choice after it. If you plan to do part C, add `lockdown=integrity` at the end and keep `iommu=pt` rather than `amd_iommu=off`.

Example for a btrfs root with the SAFE line:

```
root=PARTUUID=<root-partuuid> rootflags=subvol=@ rw rootfstype=btrfs nowatchdog audit=0 zswap.enabled=0 iommu=pt usbcore.autosuspend=-1 quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=auto lockdown=integrity
```

ext4: `rw rootfstype=ext4` and no `rootflags`. Do not add `lockdown=integrity` if you use VirtualBox, `v4l2loopback` or any DKMS module: those are built on your machine, carry no signature, and lockdown will refuse to load them.

### B3. Build the new image and make it the default

```bash
sudo mkinitcpio -P
sudo ls /boot/EFI/Linux/                     # arch-linux.efi and arch-linux-cachyos.efi
sudo rm /boot/initramfs-linux-cachyos.img    # the loose image from B1; nothing uses it now
```

Write `/boot/loader/loader.conf` in full. archinstall leaves it without a `default` line, and without one the menu picks whatever sorts first, which is the old kernel:

```
default       arch-linux-cachyos.efi
timeout       3
console-mode  max
editor        no
```

`editor no` stops anyone at the keyboard from changing the command line in the menu. Not optional once images are signed.

```bash
sudo bootctl list                            # both entries listed, cachyos marked as default
```

Do not be surprised that `cat /proc/cmdline` still shows the short line. That file shows what the running kernel booted with. It catches up after the reboot.

### B4. Reboot, check, remove the old kernel

```bash
sudo reboot
```

```bash
uname -r                                     # ends in -cachyos
cat /proc/cmdline                            # now matches /etc/kernel/cmdline
journalctl -b -k --no-pager | grep -iE "invalid for parameter|Unknown kernel command line"   # must print nothing
cat /sys/kernel/security/lockdown            # none [integrity] confidentiality, if you added lockdown
```

If `uname -r` shows the old kernel, the menu picked the wrong entry; fix `loader.conf` and reboot. If the cachyos image fails to start, choose `arch-linux.efi` in the menu and look at the preset again. Only when all four checks pass:

```bash
sudo pacman -Rns linux                       # removes the kernel and its UKI
sudo rm /etc/mkinitcpio.d/linux.preset.pacsave   # pacman keeps the edited preset under this name; nothing reads it
sudo ls /boot/EFI/Linux/                     # only arch-linux-cachyos.efi
```

**Installed the classic way already** (an entry file from step 7)? Write the preset lines from B1 by hand, run `mkinitcpio -P`, delete the entry file, set `default` in `loader.conf`, reboot once with Secure Boot still off to confirm it starts.

### B5. Maintenance: changing the kernel command line later

With a UKI the command line is inside the `.efi` file. There is no entry file to edit, and `editor no` keeps the menu from offering one. The only source is `/etc/kernel/cmdline`, and mkinitcpio reads it every time it builds the image, including on kernel updates. So the procedure is always the same three steps, before or after part C:

```bash
sudoedit /etc/kernel/cmdline          # one line; add or remove parameters on it
sudo mkinitcpio -P                     # rebuilds the UKI with the new line
sudo reboot
cat /proc/cmdline                      # shows the new line
```

After part C the sbctl hook signs the rebuilt image during `mkinitcpio -P`; `sudo sbctl verify` before the reboot confirms it if you want to see it. Until the reboot, `cat /proc/cmdline` still shows the old line, because it reports what the running kernel was started with.

Example, unlocking the GPU for LACT fan curves and clocks:

```
... systemd.show_status=auto lockdown=integrity amdgpu.ppfeaturemask=0xfff7ffff
```

`0xfff7ffff` is the driver's default `0xfff7bfff` with bit 14 added, which is the overdrive switch and the only bit LACT needs. `0xffffffff` additionally sets bit 19, graphics duty-cycle scaling. On RDNA4 the driver never reads bit 19, so on the 9070 the two values do the same thing; the RDNA2 code does read it and that is where the flicker reports come from. Use `0xfff7ffff` everywhere so the line means the same on every card. LACT's own "enable overdrive" button reaches the same result by writing `/etc/modprobe.d/99-amdgpu-overdrive.conf` and regenerating the image. Pick one of the two, not both.

---

## C. Secure Boot with your own keys

### C1. A way back

Keep a USB stick with the Arch ISO. Once Secure Boot is on, the stick will not boot until you switch Secure Boot off in the firmware again. Nothing here can lock you out of the firmware menu itself.

```bash
sudo pacman -S --needed sbctl
```

### C2. Firmware: Setup Mode and the TPM

Reboot into the firmware using the setup key listed by your motherboard vendor (commonly Delete or F2). Menu names below are examples and vary by firmware:

- **Boot → Secure Boot:** *Secure Boot Mode* **Custom** → **Key Management** → **Reset To Setup Mode** (some boards call it *Clear Secure Boot Keys* or *Delete PK*). Leave *Secure Boot* itself at Enabled; with no keys enrolled it does not enforce anything yet.
- **Settings → AMD CBS (or Miscellaneous) → AMD fTPM:** Enabled.
- **Boot → CSM Support:** Disabled.

Save, boot Linux:

```bash
sudo sbctl status            # Setup Mode: Enabled   Secure Boot: Disabled   Installed: not installed
ls /sys/class/tpm/           # tpm0
```

"sbctl is not installed" on that first run only means you have no keys yet. Next step makes them.

### C3. Make keys, sign, enrol

```bash
sudo sbctl create-keys                                   # keys land in /var/lib/sbctl/keys, root only
```

Sign the boot menu at its source, not on the ESP. `bootctl` always prefers a file ending in `.efi.signed` next to the plain one, so every copy it makes to the ESP from now on, including after systemd updates, is the signed one:

```bash
sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi
sudo bootctl install                                     # copies the signed menu to EFI/systemd and EFI/BOOT
```

`bootctl install` prints a list of "Created directory" lines even for directories that already exist, and creates a second firmware entry called "Fallback Linux Boot Manager". Both are normal; see C8 for what the fallback is.

Now the kernel image:

```bash
sudo sbctl sign -s /boot/EFI/Linux/arch-linux-cachyos.efi
sudo sbctl verify
```

`-s` records the file in sbctl's list, so the hooks re-sign it after updates. Expected output of `verify`: the `.signed` menu file, both menu copies on the ESP, and the UKI each say "is signed". One line says `/boot/vmlinuz-linux-cachyos is not signed`. That is the bare kernel file mkinitcpio reads to build the UKI; nothing ever boots it, so it needs no signature. Leave it. Do not sign anything under `/boot/EFI/Microsoft` either; Microsoft already did.

If you enabled the fallback preset in B1 you also have `arch-linux-cachyos-fallback.efi`; sign it the same way. If not, there is no such file and you skip it.

```bash
sudo sbctl enroll-keys -m
```

`-m` puts Microsoft's certificates in beside yours. Windows and some graphics-card option ROMs depend on Microsoft's signatures. Omitting them can prevent Windows from booting or leave a blank display; systems without integrated graphics may have no alternative display output. If sbctl stops with a warning about option ROMs, the answer is `-m`, never the flag that skips the check.

Reboot. Enrolling the platform key ended Setup Mode, so Secure Boot enforces from this start on.

### C4. Check

```bash
sudo sbctl status                 # Setup Mode: Disabled   Secure Boot: Enabled   Vendor Keys: microsoft
sudo bootctl status | grep -iE "secure boot|measured|tpm2"
                                  # Secure Boot: enabled (user)   Measured UKI: yes   TPM2 Support: yes
cat /sys/kernel/security/lockdown # none [integrity] confidentiality
```

If the firmware still shows Secure Boot disabled, set *Secure Boot* to Enabled once in the same menu as C2. Windows still shows in the boot menu and still boots. The Arch stick does not; expected.

`systemctl --failed` may list three TPM units: Early TPM SRK Setup, TPM NvPCR Product ID Measurement, and NvPCR Measurement of User Record. They were failing before Secure Boot too. systemd 262 tries to use a newer kind of TPM register that this board's firmware TPM does not provide. The measurements that matter, the UKI and the OS, succeed, which is what the `bootctl` line above confirms. Leave them.

### C5. Close the last door: kexec

Secure Boot stops unsigned code before the kernel runs. `lockdown=integrity` from B2 stops root from getting around it afterwards: no unsigned modules, no writing to kernel memory, no replacing the running kernel with an unsigned one. kexec, the system call that swaps the running kernel without going through the firmware, is still allowed for signed images. Close it too:

```bash
echo 'kernel.kexec_load_disabled = 1' | sudo tee /etc/sysctl.d/99-lockdown.conf
sudo sysctl --system
sysctl kernel.kexec_load_disabled # 1
```

This touches nothing else. The TPM, every app that uses it, and crash-free reboots through the firmware all work as before. It only matters if you wanted kdump or a kexec fast reboot, which this guide does not use.

### C6. Maintenance: updates, and what signs them

You do nothing on updates. The sbctl package installs two hooks:

- **A mkinitcpio hook** that runs every time an image is built and signs the UKI it just made. Kernel updates and a hand-run `mkinitcpio -P` both go through it.
- **A pacman hook** that runs after any package transaction touching `/boot`, kernel modules or an `.efi` file, and re-signs every file you registered with `-s`. That includes the `.signed` menu file in `/usr/lib` when systemd updates.

The menu copy on the ESP is not replaced by anything automatic: `systemd-boot-update.service` is off by default and the Arch systemd package ships no hook for it. The ESP keeps the menu from C3 until you run `sudo bootctl update`, which copies the re-signed file. Do that after systemd updates if you want the newer menu; it is never required.

After the first kernel update, once:

```bash
sudo sbctl verify
```

### C7. Back up the keys

Copy `/var/lib/sbctl` somewhere that is not this disk. It holds the private keys. Lose them and a reinstall means enrolling new ones from Setup Mode again. Five minutes, but only if you remember how.

### C8. What the fallback is, and what a CMOS clear does

`bootctl install` put the signed menu in two places: `EFI/systemd/systemd-bootx64.efi`, which the firmware's "Linux Boot Manager" entry points at, and `EFI/BOOT/BOOTX64.EFI`, the path every UEFI firmware checks when it has no entries of its own. The second file is the fallback. The firmware entry named "Fallback Linux Boot Manager" just points at it; the entry is cosmetic, the file is the safety net. Delete the entry with `efibootmgr -b <id> -B` if the duplicate in the boot menu bothers you. Keep the file.

A CMOS clear wipes the firmware's boot entries and resets Secure Boot to the factory keys. Nothing on the disk changes. Your home, your SSH keys and keyrings, every saved app login, all stay as they were; none of them is tied to the TPM or the firmware. The way back is in the panic section at the end of this file.

### C9. If it does not boot

- **Firmware says the image failed verification:** Secure Boot Disabled in the firmware → boot → `sudo sbctl verify` → sign what is unsigned → enable again.
- **Black screen at power-on right after enrolment:** keys went in without `-m`. Clear CMOS (jumper or battery), then C8.
- **A module refuses to load:** `journalctl -b -k | grep -i "module verification"`. Lockdown refusing an unsigned module. Remove the package or drop `lockdown=integrity` from B2.
- **Remove all of it:** `sudo sbctl reset`, then Secure Boot Disabled in the firmware. The UKI from part B keeps booting unsigned.

---

## Panic: the CMOS got cleared

You pressed the clear button, pulled the battery, flashed the firmware, or the board did it after a failed overclock. You know it happened because the firmware greets you with its first-run screen, the clock is wrong, and then one of these:

- a message like *Secure Boot Violation*, *Image failed verification* or *Invalid signature detected*, then nothing;
- Windows starts as if Linux were gone;
- *No bootable device* or *Reboot and Select proper Boot device*.

Nothing is lost. The disk was not touched. The firmware forgot two things: that your disk has a boot entry, and that your key is allowed. Both go back in ten minutes. Do not reinstall, do not run the Arch stick, do not touch `/boot` from Windows.

**1. Firmware: Secure Boot off, and the three settings the clear reset.**
Power on, hold Delete. Then:

- **Boot → Secure Boot:** *Secure Boot* **Disabled**. With the factory keys back, the firmware would refuse your menu and your kernel, so enforcement has to be off to get in.
- **Settings → AMD CBS (or Miscellaneous) → AMD fTPM:** Enabled. The clear turned it off.
- **Boot → CSM Support:** Disabled. The clear may have turned it on.
- Set the date and time while you are there.

Save and exit.

**2. Get to the boot menu.**
If systemd-boot's menu appears, go to step 3. If Windows starts or the firmware says there is no bootable device, power off, power on, and use the boot-menu key documented by your motherboard vendor (often F8, F11, or F12). Pick the Linux boot disk, the line that says *UEFI OS* or the disk's model name, not the Windows Boot Manager line. That runs `EFI/BOOT/BOOTX64.EFI`, which is your signed systemd-boot, and the usual menu appears. Choose the cachyos entry.

**3. In Linux: give the firmware its entries back.**

```bash
sudo bootctl install          # recreates "Linux Boot Manager" and the fallback entry
sudo sbctl status             # Setup Mode: Disabled   Secure Boot: Disabled   Vendor Keys: microsoft or none
sudo sbctl verify             # every file still "is signed": the signatures live on the disk, not in the firmware
```

`verify` passing is the proof that nothing has to be re-signed. From here the machine boots on its own again, just without Secure Boot. If that is enough for today, stop; the rest can wait.

**4. Firmware again: back into Setup Mode.**
Reboot, hold Delete. **Boot → Secure Boot:** *Secure Boot Mode* **Custom** → **Key Management** → **Reset To Setup Mode**. Set *Secure Boot* back to **Enabled**; with no owner key it enforces nothing yet. Save and exit. Linux boots as normal.

**5. In Linux: enrol the same keys again.**

```bash
sudo sbctl status             # Setup Mode: Enabled
sudo sbctl enroll-keys -m     # same keys from /var/lib/sbctl; -m for Windows and the graphics card, as in C3
sudo reboot
```

**6. Check.** The three lines from C4:

```bash
sudo sbctl status             # Setup Mode: Disabled   Secure Boot: Enabled   Vendor Keys: microsoft
sudo bootctl status | grep -iE "secure boot|measured"
cat /sys/kernel/security/lockdown
```

Lockdown and the kexec sysctl never went away: one is in the kernel command line inside the UKI, the other in `/etc/sysctl.d`. The firmware is the only thing that was reset, and it is now back to where C4 left it.

**If step 2 gives a black screen** instead of a menu, the card's option ROM is being refused. That only happens with Secure Boot enforcing and no Microsoft certificates. After a CMOS clear the factory keys include Microsoft's, so this should not occur; if it does, clear CMOS once more and make sure step 1 really set Secure Boot to Disabled before saving.

**If `/var/lib/sbctl` is gone** (new disk, or you never did C7), the old signatures are worthless and you start part C from C3: new keys, sign everything again, enrol. The panic steps above still get you booting first.
