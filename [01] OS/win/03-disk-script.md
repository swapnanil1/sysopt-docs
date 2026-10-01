# Step 3: The disk script (form section 3, Windows PE stage)

## What this step is

This is part of step 2. You paste [unattend/pe.cmd](unattend/pe.cmd) into section 3 of the generator form and the generator copies it into your `autounattend.xml`. It runs from the USB stick before Windows is on the disk, so you never run it by hand.

The copy in this repo can't wipe anything yet. Both size limits are `expected = 0`, which no disk matches, so it stops with `No disk satisfied the given criteria`. It only works once you put in your own size range (section 3.3).

This is the section that decides how the disk gets wiped. Read it twice.

The section has three radio buttons at the top level: *Run the Windows PE stage interactively*, *Generate a .cmd script*, and *Provide your own .cmd script to handle the entire Windows PE stage*. We use the third one.

**Set:** scroll to the bottom of the section, select **Provide your own .cmd script to handle the entire Windows PE stage**. The text box contains a sample script. Select all, delete, and paste the full contents of [unattend/pe.cmd](unattend/pe.cmd).

**The moment you select it, everything else in this section greys out**: the edition and product key box, the six checkboxes, the image picker, the target-disk criteria, the partition layout, the system partition size, the Windows RE choice, the diskpart box and the paging-file choice. That is expected. Those controls only exist to *generate* a script, and we are supplying the whole script ourselves. Every one of those options is now a line in `pe.cmd`, and the rest of this section maps each greyed-out control to that line so you know what the script is doing and where to change it.

**Why the custom script instead of the generated one:** the generator's own script always creates a 16 MB MSR partition and, unless you remove RE, a recovery partition, and it falls back to legacy MBR if the PC booted in BIOS mode. The only way to get our two-partition layout (EFI + Windows) **and** keep the automatic target-disk detection is to take the generated script and edit it. That is what `pe.cmd` is: the generator's output with the MSR, recovery, MBR, `$OEM$` and Defender blocks removed.

## 3.1 What pe.cmd does, in order

1. Sets the US keyboard for the PE session.
2. Searches every drive letter for `sources\install.wim` (the ISO) and `autounattend.xml`. It also reads the path Ventoy injects into the registry, which is how the Ventoy method in [05-flash-usb.md](05-flash-usb.md) works.
3. Loads any drivers from a `$WinPEDriver$` folder on the USB, if present (not needed on this hardware).
4. Writes a small VBScript that lists all disks and accepts only those inside your size range (for example 400 to 600 GiB for a 512 GB drive), on a SCSI or IDE interface (that is how NVMe and SATA report), and of type fixed disk. Exactly one match, or it halts.
5. Checks the firmware type. **If not UEFI, it stops with an error** rather than falling back to MBR.
6. Runs diskpart: clean, convert GPT, 300 MB EFI (FAT32, "System"), rest NTFS ("Windows").
7. Applies the image named `Windows 11 Pro` with `/CheckIntegrity /Verify`.
8. `bcdboot` writes the boot loader to the EFI partition and sets it first in the firmware boot order.
9. Copies the answer file to `W:\Windows\Panther\unattend.xml` so the later passes can read it.
10. Disables 8.3 names on the new volume and in the registry hive of the new install.
11. Sets the device region (United States, GeoID 244, in the repo's copy) in the offline registry.
12. Reboots.

## 3.2 Greyed-out control → line in pe.cmd

**Windows edition to install** (product key radio buttons). In script mode the edition is chosen by image name, not by key, so there is no key anywhere in our file. The line is:

```bat
set "IMG_PARAM=/Name:"Windows %OS_VERSION% Pro""
```

`%OS_VERSION%` is worked out a few lines earlier from the PE build number, so this expands to `Windows 11 Pro`. **CHANGE** only if step 1 section 5 showed a different image name. Windows 11 Pro activates itself from the digital license tied to your motherboard once online. If you have a retail key you want applied, add it in section 4 (Activation) instead.

**The six checkboxes:**

| Checkbox | In pe.cmd | Why |
|---|---|---|
| Disable 8.3 file names | **Present.** The block starting `call :print "Disabling 8.3 file names"`: two `fsutil.exe 8dot3name` commands plus a registry write into the new install's SYSTEM hive. | NTFS otherwise generates a second `PROGRA~1`-style name for every file. Creating files in large folders is measurably faster without it, and nothing modern needs short names. Delete the six lines to keep 8.3 names. |
| Disable Windows Defender | **Absent.** The generated version has a `call :print "Disabling Windows Defender"` block that sets six Defender services to Start=4 in the offline hive. It was removed. | Defender is the only antivirus in this build. Turning it off saves some CPU during file copies and leaves you with no protection at all. Not worth it. |
| Pause before disk is partitioned and formatted | **Absent.** To add it, insert a line containing just `pause` directly above `diskpart.exe /s X:\%LAYOUT%.txt`. | We want zero clicks. Add it for your very first test run if you are nervous: the screen above the pause shows which disk number it is about to wipe. |
| Pause before Windows Setup reboots | **Absent.** To add it, insert `pause` directly above `wpeutil.exe reboot`. | Same. Lets you read the whole PE log before it scrolls away. |
| Apply Windows image in compact mode | **Absent.** It would be a `/Compact` switch on the `dism.exe /Apply-Image` line. | Compact mode compresses every system file on disk. Saves about 2 GB, but every read of a system file pays a decompression cost on the CPU forever. On any SSD of 256 GB or more that trade is backwards. |
| Skip integrity check when applying image | **Not skipped.** The `dism.exe /Apply-Image` line keeps `/CheckIntegrity /Verify`. | The check adds about a minute and catches a corrupt USB or ISO before you spend an hour on a broken install. Delete those two switches to skip it. |

**Windows image to install.** Same `IMG_PARAM` line as above. The generator's "by index" and "interactive" options have no equivalent in our script; by name is the safe choice because a single-edition ISO has exactly one name.

**Select target disk.** The VBScript block between `>X:\target.vbs (` and the closing `)`. Each generator criterion is one `If` test:

| Generator criterion | In pe.cmd | Why |
|---|---|---|
| Must not contain any existing partitions | **Absent.** Would be `If drive.Partitions > 0 Then accept = False`. | We are reinstalling over an old Windows; the disk has partitions. |
| Connected to a SATA, SCSI, SAS or NVMe controller | **Present.** `If actual <> "SCSI" And actual <> "IDE" Then accept = False` on `drive.InterfaceType`. | Excludes USB sticks and USB SSDs, including the install stick itself. NVMe reports as SCSI, SATA as IDE. |
| Media type Fixed hard disk | **Present.** `If actual <> "Fixed hard disk media"` on `drive.MediaType`. | Second guard against removable media. |
| Capacity between X and Y GiB | **Present.** Two `expected =` lines, first the minimum, then the maximum. The repo's copy has `0` in both. | **CHANGE** to bracket your target drive. A 512 GB drive reports about 476 GiB, so use 400 and 600; a 1 TB drive about 931 GiB, so use 900 and 1000. Check Disk Management. If two disks fall in the range, unplug one; the script refuses to guess and halts. |
| Must have this index number | **Absent.** Would be `If drive.Index <> 0`. | Disk 0 is not reliably the boot drive. Never rely on it. |

If none or more than one disk passes, the script prints `No disk satisfied` or `Several disks (...) satisfied` and halts **before** touching anything.

**Choose partition layout.** The `for /f ... PEFirmwareType` block followed by:

```bat
if not %LAYOUT% == GPT call :fail "Not booted in UEFI mode. ..."
```

The generator's *Automatic* would write both a `GPT.txt` and an `MBR.txt` and pick one. Ours writes only `GPT.txt` and refuses to continue on a BIOS/CSM boot. **Why:** GPT is required for UEFI, and there is no reason to ever let this script produce a legacy install by accident.

**Configure system partition.** In the `>X:\GPT.txt (` block: `CREATE PARTITION EFI SIZE=300`. **Why 300 MB:** Microsoft's minimum is 100. 300 leaves room for firmware update capsules and a second boot loader if you dual-boot. Costs nothing.

**Choose how to install Windows RE.** Equivalent to *Remove Windows RE*: the `GPT.txt` block has no third partition and no `SET ID=de94bba4-...` line. **Why:** the recovery partition holds "Reset this PC" and the repair tools. It costs a partition and about 1 GB, and it is what broke Windows Update in 2024 (KB5034441 "recovery partition too small"). With an unattended USB a full reinstall to a clean desktop takes 10 minutes, which is a better recovery tool than WinRE. Shift+F10 in Setup still gives you a command prompt for repairs.

**Use a custom diskpart script.** This is what the whole `GPT.txt` block is. Ours, compared to the generator's default, drops two lines: `CREATE PARTITION MSR SIZE=16` and everything after `ASSIGN LETTER=W`. Result:

```
SELECT DISK=%TARGET_DISK%
CLEAN
CONVERT GPT
CREATE PARTITION EFI SIZE=300
FORMAT QUICK FS=FAT32 LABEL="System"
ASSIGN LETTER=S
CREATE PARTITION PRIMARY
FORMAT QUICK FS=NTFS LABEL="Windows"
ASSIGN LETTER=W
```

**Why no MSR:** the Microsoft Reserved partition is a hidden 16 MB area Windows keeps for converting basic disks to dynamic disks and for some legacy BitLocker metadata. This build prevents device encryption (section 14) and nobody uses dynamic disks any more, so it would sit empty forever. Windows boots, updates and upgrades fine without it. If a disk tool ever complains, `diskpart` can add one in seconds. Drive letters S: and W: exist only inside PE; the installed Windows is always C:.

**Paging file.** Not touched by the script, which is the same as *Let Windows manage paging file size*. **Why:** with 16 GB of RAM or more the page file stays small and idle. Removing it does not speed anything up, but it breaks programs that reserve more memory than they use (many games do) and disables crash dumps. Leave it.

**Region line.** Not a generator control in this section (it comes from *Home location* in section 2), but it is in the script:

```bat
call :print "Setting device setup region to United States (GeoID 244)"
reg.exe ADD "...\DeviceRegion" /v DeviceRegion /t REG_DWORD /d 244 /f
```

**CHANGE** `244` (and the text) to your country: India 113, United States 244, United Kingdom 242, Germany 94, Canada 39, Australia 12, Japan 122. Full list: search "Table of Geographical Locations" on learn.microsoft.com.

## 3.3 Summary of lines to CHANGE in the pasted script

| Find | Change to |
|---|---|
| the first `expected = 0`, then the second `expected = 0` | the minimum, then the maximum, of your disk's size bracket in GiB |
| `set "IMG_PARAM=/Name:"Windows %OS_VERSION% Pro""` | leave unless your image name differs |
| `United States (GeoID 244)` and `/d 244` | your country's name and GeoID |
| `wpeutil.exe SetKeyboardLayout 0409:00000409` | leave unless you need a non-US layout while typing in PE, which an unattended run never does |

---

## Check

Before you leave the text box: the two `expected =` lines have your minimum and maximum in them, not `0`, and exactly one internal disk in the PC falls inside that range.

Next: back to [02-answer-file.md](02-answer-file.md#4-activation), section 4.
