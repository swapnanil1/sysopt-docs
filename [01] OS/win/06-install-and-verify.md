# Step 6: Install, verify, change later

## What this step is

The install itself, what to check on the fresh desktop, and how to change the answer file afterwards.

## Install day checklist

**Test in a VM first if you can.** VirtualBox or Hyper-V with a 450 GB dynamically-allocated disk (it only uses what it writes), EFI enabled, 4 GB RAM. The whole run takes 15 minutes and shows you every window the real install will show. Tick the matching *VM guests* option in section 19 for that test file only.

On the real machine:

1. **Back up.** The script wipes the disk that matches the size rule without asking.
2. **Unplug or check every other disk.** If a second disk is also inside your size range, the script halts with "Several disks satisfied the given criteria" (safe, but you have to unplug one). If nothing matches, it halts with "No disk satisfied". Both leave the old disk untouched.
3. **BIOS:** UEFI mode on, CSM off, Secure Boot on, fTPM / PTT on, boot from USB. On most ASUS, MSI and Gigabyte boards these are under Boot and Advanced → CPU Configuration.
4. **Ethernet cable connected.** Wi-Fi setup is skipped.
5. Boot the stick. Ventoy: pick the ISO, then **Boot with autounattend.xml template**. Rufus: it just starts.
6. Watch the PE window. It prints each step with `*** ... ***` markers. On any error it stops with `Fatal error:` and waits for a key. Nothing was written yet if the error is before "diskpart will now wipe".
7. Reboot happens by itself. Let it boot from the disk (remove the stick if the BIOS insists on USB first).
8. Specialize pass: a few PowerShell windows appear and close on their own. Do not close them.
9. Desktop appears, signed in as your user. Three PowerShell windows run in sequence, Explorer restarts. **Reboot once more** when they finish; several policies only take effect after that.

**If the Ventoy boot hangs at a black screen or "no drivers found",** press Ctrl+W in the Ventoy menu to switch to WIMBOOT mode and boot the ISO again.

---

## After the install

1. Read `C:\post-install-logs\perf.log`, `privacy.log`, `interface.log`. Review errors and warnings, including the Defender blocked/failed count. An apparently successful registry write does not prove that the running engine applied it.
2. Install the chipset driver and the GPU driver from the vendor's site (AMD, Intel or NVIDIA). Windows Update will not touch them (section 26).
3. Install a browser. There is no Edge.
4. Install a launcher. Windows search is off in this build, so typing in Start finds nothing. The build expects [Open-Shell](https://github.com/Open-Shell/Open-Shell-Menu) as the Start menu. In its installer keep only *Open-Shell Menu*. Everything or pinned apps work too. Skip this if you deleted the search-off lines in step 4.
5. Install a text editor if you left Notepad out in step 1 (Notepad++ is one download), and winget if you left App Installer out (see step 1 section 3).
6. Run **Windows Update** once. Install applicable updates, then verify the Defender state again; updates may restore disabled settings.
7. Install your chosen **third-party antivirus** and verify in its own interface that real-time protection and updates are active. This setup does not install a replacement antivirus automatically. Open **Windows Security**. Defender antivirus being unavailable/off is expected with this PE script; do not expect everything to be green. In an elevated PowerShell, check `Get-CimInstance Win32_Service -Filter "Name='WinDefend'" | Select-Object Name,State,StartMode` for `Stopped` and `Disabled`. Core isolation → Memory integrity shows **Off** with a yellow warning if you kept section 18's *Disable core isolation*, and **On** if you chose to keep it. App & browser control → Smart App Control also shows **Off**. The privacy log records policy readbacks, service/driver states and any blocked changes. The Security tray icon is intentionally removed from startup; its absence is not proof that antivirus is off. Reboot before checking loaded-driver changes.
8. If you change your mind about memory integrity, flip it in Windows Security → Device security → Core isolation and reboot. Section 18 says what it costs.
9. There is no recovery partition. For Safe Mode tap F8 right after the firmware logo (the perf script turns the old boot menu on). For anything worse, reinstall from the USB stick.
10. Optional: add the firewall allowlist from [07-firewall.md](07-firewall.md).

---

## Changing something later

You do not have to redo the form. Go to the generator, **Import .xml file** → your `autounattend.xml`, change the setting, download again, and replace the file on the stick. For a script change, edit the `.ps1` in this repo, paste it into the FirstLogon box again, download. The generator preserves everything else.
