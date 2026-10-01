# Step 1: Build a minimal, official Windows 11 Pro ISO with UUP dump

## What this step is

Download Windows 11 straight from Microsoft's update servers and turn it into an ISO that contains only the Pro edition, the latest cumulative update, and none of the Store apps you never asked for. [Step 2](02-answer-file.md) builds the `autounattend.xml` answer file that installs that ISO with zero clicks.

Nothing in this guide patches a system file, removes Defender, or breaks Windows Update. Everything is done with Microsoft's own tools (DISM) or documented settings, so the result is a normal, fully supported Windows install that just has less junk in it.

---

## 0. Why build your own ISO instead of using the Media Creation Tool or AtlasOS / ReviOS / AME

| Option | What you get | Problem |
|---|---|---|
| Media Creation Tool ISO | Every edition, every inbox app, an old cumulative update | First boot spends 30+ minutes downloading updates and re-installing Store apps you then have to remove one by one. |
| AtlasOS / ReviOS / AME "playbooks" | Very lean | They delete or patch system components after install. Cumulative updates can fail or undo the changes, Defender is often gone, and you are trusting a third party's scripts with your kernel. |
| **UUP dump (this guide)** | Official Microsoft files, single edition, latest update already integrated, only the Store apps you list | You need 30 to 60 minutes of build time and about 25 GB of free disk space once. |

The key idea: with UUP dump the unwanted apps are **never put into the image**. There is nothing to "debloat" afterwards because it was never there.

---

## 1. What you need

- A Windows 10 or 11 PC to build on (the build script is Windows-only for the "include updates" option).
- About **25 GB free** on the drive you build on (roughly 6 GB download, the rest is temporary working space).
- A folder path **without spaces**. `D:\uup` is fine. `C:\Users\My Name\Desktop\uup` is not. The build script refuses to run from a path with spaces.
- Administrator rights on that PC.
- A stable internet connection. The download is resumable, so a dropped connection is not fatal.

---

## 2. Pick the build on uupdump.net

1. Open <https://uupdump.net>.
2. Under **Quick options**, click **Latest Public Release build** and choose **x64**.
   This lists builds that Microsoft has actually shipped to the public. Avoid Beta, Dev and Canary unless you know why you want them.
3. Click the newest build. In this repo the build used was:

   ```
   26300.9539  (Windows 11, version 26H2)
   ```

   If uupdump shows both 25H2 and 26H2, either is fine. Take the newest one that says "Public Release" and is not marked as a preview.
4. **Language:** choose the language you want Windows to be in. We used **English (United States)**. Remember this choice, step 2 must use the same language.
5. **Edition:** tick **Windows Pro** only. Untick Windows Home.
   Reason: one edition means a smaller download, a faster build, and an ISO with exactly one image in it. The disk script (step 3) picks the image by name ("Windows 11 Pro"), so a single-image ISO leaves no room for a wrong pick.
6. **Download method:** choose **Download and convert to ISO**.
   Tick **Include updates (Windows converter only)**. Leave the other checkboxes at their defaults; the next section replaces the config file anyway.
7. Click **Create download package**. You get a small ZIP (a few hundred KB). It contains scripts, not Windows itself.

---

## 3. Unpack and configure

1. Extract the ZIP into your no-spaces folder, e.g. `D:\uup`. You should see:

   ```
   uup_download_windows.cmd     <- the one you will run
   uup_download_linux.sh
   uup_download_macos.sh
   ConvertConfig.ini            <- conversion settings
   CustomAppsList.txt           <- which Store apps to include
   files\                       <- helper scripts, leave alone
   ```

2. Replace the contents of `ConvertConfig.ini` with this repo's version, [iso/ConvertConfig.ini](iso/ConvertConfig.ini). Every line explained:

   ```ini
   [convert-UUP]
   AutoStart    =1   ; start converting as soon as the download finishes, no prompt
   AddUpdates   =1   ; slipstream the latest cumulative update into install.wim
   Cleanup      =1   ; DISM component cleanup: delete superseded files left behind by the update
   ResetBase    =1   ; make the cleanup permanent, smaller image, faster install and servicing
   NetFx3       =1   ; include .NET Framework 3.5 (older games/tools need it; saves a download later)
   StartVirtual =0   ; do not create "virtual" editions (Enterprise, Education...) from Pro
   wim2esd      =0   ; keep install.wim, do not recompress to install.esd
   wim2swm      =0   ; do not split the wim (only needed for FAT32 sticks; we use Ventoy/exFAT)
   SkipISO      =0   ; yes, produce the .ISO at the end
   SkipWinRE    =1   ; do not spend time updating the recovery image; step 3 makes no recovery partition
   LCUwinre     =0   ; (only matters when SkipWinRE=0)
   LCUmsuExpand =0   ; (advanced, leave)
   UpdtBootFiles=1   ; refresh boot.wim / bootmgr with the updated versions
   ForceDism    =1   ; use Microsoft's DISM for integration instead of wimlib, slower but the "official" path
   RefESD       =0   ; do not create reference ESDs
   SkipLCUmsu   =0   ; (advanced, leave)
   SkipEdge     =1   ; do NOT bake Microsoft Edge into the image
   AutoExit     =0   ; leave the window open at the end so you can read the result
   DisableUpdatingUpgrade=0
   AddDrivers   =0   ; no drivers injected at build time (Windows has NVMe/USB/network drivers inbox)
   Drv_Source   =\Drivers

   [Store_Apps]
   SkipApps     =0   ; 0 = still process the app list (we want exactly one app)
   AppsLevel    =0
   StubAppsFull =0
   CustomList   =1   ; use CustomAppsList.txt instead of the default "install everything"

   [create_virtual_editions]
   vUseDism     =1
   vAutoStart   =1
   vDeleteSource=0
   vPreserve    =0
   vwim2esd     =0
   vwim2swm     =0
   vSkipISO     =0
   vAutoEditions=
   vSortEditions=
   ```

   Why these matter for a lean system:

   - **AddUpdates + Cleanup + ResetBase** is what makes first boot fast. The cumulative update is already applied, and the superseded files it replaced are gone, so `C:\Windows\WinSxS` starts several GB smaller and Windows Update has nothing big to do on day one.
   - **SkipEdge=1** removes Edge entirely. Edge normally installs two background services and a startup-boost task that keep a browser process resident even when you never open it. Install Firefox, Brave or Chrome yourself afterwards. If you want Edge, set this to 0.
   - **wim2esd=0** trades about 1 GB of ISO size for install speed. ESD uses a heavier compression that DISM has to undo file by file while applying the image.
   - **SkipWinRE=1** skips work we throw away: step 3 installs without a recovery partition. Reinstalling from the USB takes 10 minutes unattended, which is faster and more reliable than "Reset this PC". The perf script in step 4 turns the old F8 boot menu back on, so Safe Mode is still reachable.

3. Open `CustomAppsList.txt`, or replace it with this repo's version, [iso/CustomAppsList.txt](iso/CustomAppsList.txt). Every line starting with `#` is an app that will **not** be in the image. Only uncommented lines are installed. Our list keeps exactly one:

   ```
   Microsoft.SecHealthUI_8wekyb3d8bbwe
   ```

   That is the **Windows Security** app, the UI for Defender. Without it Defender still runs, but you cannot see or change it.

   Everything else (Store, Photos, Camera, Calculator, Xbox, Teams, Outlook, Copilot, Clipchamp, Widgets, Terminal, Notepad, Paint, App Installer, all codecs...) stays commented out and is never installed.

   **Things to consider un-commenting before you build.** These are cheap and hard to add back later without the Store:

   | Line | What it is | Why you might want it |
   |---|---|---|
   | `Microsoft.DesktopAppInstaller_8wekyb3d8bbwe` | App Installer = **winget** | Without it there is no `winget` command. Installing it manually later needs three dependency packages. Costs about 20 MB, no background process. |
   | `Microsoft.WindowsNotepad_8wekyb3d8bbwe` | Notepad | Windows 11 has no classic notepad.exe any more. With this line commented out you have **no text editor at all** until you install one. |
   | `Microsoft.WindowsTerminal_8wekyb3d8bbwe` | Windows Terminal | Optional. `cmd.exe` and `powershell.exe` still exist and open in the classic console. |
   | `Microsoft.HEVCVideoExtension_8wekyb3d8bbwe`, `Microsoft.AV1VideoExtension_8wekyb3d8bbwe`, `Microsoft.WebpImageExtension_8wekyb3d8bbwe` | Codecs | Only needed if you use Windows' own media apps or thumbnails for those formats. VLC, mpv and browsers bring their own. |

   Apps in this list are Store packages. They do not run at boot; the cost of an unused one is only disk space. The reason to leave them out is that many of them re-register background tasks, ads and Start pins, and having them gone removes an entire class of "why is this running" questions.

---

## 4. Run the build

1. Right-click `uup_download_windows.cmd` and choose **Run as administrator**.
   If SmartScreen complains, click **More info** then **Run anyway**. The script is plain text; you can open it in any editor to see what it does.
2. The script downloads `aria2c` (a download tool), then fetches about 6 GB of `.cab`/`.esd`/`.msu` files from Microsoft's servers into `UUPs\`.
3. When the download completes it starts the converter automatically (that is `AutoStart=1`). You will see DISM output scrolling for 20 to 60 minutes. The **Cleanup/ResetBase** step is the slow one and looks stuck at a percentage for a while. It is not stuck.
4. When you see the ISO creation finish and the window says it is done, the ISO is in the same folder:

   ```
   26300.9539.260907-1819.26H2_GE_RELEASE_SVC_PROD3_CLIENTPRO_OEMRET_X64FRE_EN-US.ISO
   ```

   Expect roughly 4.5 to 5.5 GB. You can now delete the `UUPs\` folder to get your disk space back, or keep it to rebuild later without downloading.

**If the build fails**, the last screen of text says why. The three common causes are: a path with spaces, an antivirus other than Defender quarantining the converter's tools, or running out of disk space during Cleanup. Fix the cause, delete everything except `UUPs\`, re-extract the ZIP, and run again. The download resumes.

---

## 5. Verify the ISO before you use it

The disk script (step 3) selects the image inside the ISO **by name**, and that name must be exactly `Windows 11 Pro`. Check it once:

1. Right-click the ISO and choose **Mount**. It appears as a new drive letter, say `E:`.
2. Open PowerShell and run:

   ```powershell
   Get-WindowsImage -ImagePath E:\sources\install.wim
   ```

   You should see exactly one entry:

   ```
   ImageIndex  : 1
   ImageName   : Windows 11 Pro
   ```

3. Also confirm the folder `E:\sources` contains `install.wim` (not `install.esd`). Both work with the disk script, but `.wim` is what our config produces.
4. Right-click the mounted drive and choose **Eject**.

If the name is different (for example `Windows 11 Pro N` because you picked an N edition), write it down. [03-disk-script.md](03-disk-script.md) tells you where to change it.

---

## 6. What is in the image now, and what is not

**In:** Windows 11 Pro 26H2 with the latest cumulative update, .NET 3.5, Windows Security app, all inbox drivers, Defender, all Windows features (Hyper-V, WSL, Sandbox can still be enabled).

**Not in:** Microsoft Edge, Microsoft Store, every other Store app, superseded update files, recovery-image updates.

Because nothing was deleted from the OS itself, **Windows Update works normally** and future cumulative updates install fine. If Microsoft pushes a feature update (for example 27H1), it may bring some apps back; the answer file from step 2 includes a safety-net removal list and a policy that stops silent app re-installs.

Next: [02-answer-file.md](02-answer-file.md).
