# Step 5: Flash the USB

## What this step is

Put the ISO from step 1 and your `autounattend.xml` from step 2 on a USB stick that installs Windows without any clicks.

You need a USB stick of **8 GB or more**. Everything on it will be erased.

## Method A: Ventoy (what this repo uses)

Ventoy turns the stick into a boot menu that boots any ISO you copy onto it, and it can inject the answer file for you. You can keep several ISOs on one stick.

1. Download Ventoy for Windows from <https://www.ventoy.net/en/download.html> and extract it.
2. Run `Ventoy2Disk.exe`. Menu **Option** → tick **Secure Boot Support**. Menu **Option → Partition Style → GPT**. Select your USB stick under *Device* and click **Install**. Confirm twice. This takes a few seconds and only needs to be done once per stick.
3. The stick now shows up as a drive named `Ventoy`. Copy onto its root:
   - the ISO from step 1 (keep the long name or rename it; just be consistent below),
   - your `autounattend.xml`.
4. Create a folder named `ventoy` on the stick and inside it a file `ventoy.json` with this content (this repo's [unattend/ventoy.json](unattend/ventoy.json)):

   ```json
   {
       "auto_install": [
           {
               "image": "/26300.9539.260907-1819.26H2_GE_RELEASE_SVC_PROD3_CLIENTPRO_OEMRET_X64FRE_EN-US.ISO",
               "template": "/autounattend.xml"
           }
       ]
   }
   ```

   **CHANGE** `image` to the exact file name of your ISO, including the leading `/`. It is case-sensitive. The stick's layout is then:

   ```
   Ventoy (D:)
   ├── 26300.9539....ISO
   ├── autounattend.xml
   └── ventoy\
       └── ventoy.json
   ```

5. **Why Ventoy:** the same stick can carry a Linux ISO, a rescue ISO and a second Windows build; you rebuild nothing when the ISO changes (copy the new file, edit one line in the JSON); and the answer file is injected into the ISO's boot image at boot, which is what the `reg.exe query HKLM\System\Setup /v UnattendFile` line in `pe.cmd` reads.

**Secure Boot first-time enrolment.** The first time you boot the stick with Secure Boot enabled you get a blue "Verification failed" screen. This is expected. Choose **OK → Enroll key from disk → VTOYEFI → ENROLL_THIS_KEY_IN_MOKMANAGER.cer → Continue → Yes → Reboot**. It never asks again on that PC.

## Method B: Rufus (single ISO, no menu)

Use this if Ventoy fails to boot on a particular board.

1. Download Rufus from <https://rufus.ie>. Run it.
2. *Device:* your stick. *Boot selection:* SELECT → your ISO. *Partition scheme:* **GPT**. *Target system:* **UEFI (non CSM)**. *File system:* NTFS. Click **START**.
3. Rufus shows a **Windows User Experience** dialog with its own tweaks (remove requirements, local account, disable data collection...). **Untick every box.** Rufus implements those by writing its own `autounattend.xml`, which would fight with ours.
4. When Rufus finishes, copy your `autounattend.xml` to the **root** of the stick. `pe.cmd` finds it by scanning drive letters.

---

Next: [06-install-and-verify.md](06-install-and-verify.md).
