# Step 2: Build your own autounattend.xml

## What this step is

Step 1 gave you a lean Windows 11 Pro ISO. This step builds the answer file that installs it with **zero clicks**, wipes and partitions the disk the way we want (EFI + Windows only, no MSR, no recovery partition), skips every OOBE screen, removes the leftovers, and applies our performance, privacy and interface settings on first logon. [Step 5](05-flash-usb.md) then puts everything on a USB stick.

The answer file is made with the free unattend generator at <https://schneegans.de/windows/unattend-generator/>. This guide walks the form **top to bottom in the same order as the website**, so keep the site open in one window and this file in the other. For every option it says what we set and why. "Why" is always one of: saves CPU or RAM, makes install or boot faster, or removes a Windows 11 annoyance. Where a choice costs security, it says so.

Section numbers in steps 2, 3 and 4 are the generator's form sections. Sections 3 and 26 are where you paste files from this repo, so each has its own page.

**Files from this repo you will paste into the form:**

| File | Goes into | Explained in |
|---|---|---|
| [unattend/pe.cmd](unattend/pe.cmd) | Section 3, Windows PE stage → *Provide your own .cmd script* | [03-disk-script.md](03-disk-script.md) |
| [scripts/01-perf.ps1](scripts/01-perf.ps1) | Section 26, Run custom scripts → FirstLogon script 1 | [04-first-logon-scripts.md](04-first-logon-scripts.md) |
| [scripts/02-privacy.ps1](scripts/02-privacy.ps1) | Section 26, Run custom scripts → FirstLogon script 2 | same |
| [scripts/03-interface.ps1](scripts/03-interface.ps1) | Section 26, Run custom scripts → FirstLogon script 3 | same |

The generator copies all four into the XML. Setup runs them from the XML, it never reads the standalone files.

**Building your own:** go through sections 1 to 29 below and set each field. Anything personal to you is marked **CHANGE**.

**Shortcut:** the generator has **Import .xml file** at the very top. Import [unattend/autounattend.example.xml](unattend/autounattend.example.xml) and the form fills itself in with this guide's choices. The personal values in it are placeholders (user `User`, computer `MY-PC`, time zone `UTC`, region United States, and a disk rule that matches no disk), so you still have to set every **CHANGE** value. Read the rest anyway so you know what the file does to your machine.

Don't put the example on a USB stick as it is. Its disk rule matches nothing, so the install would just stop.

---

## How the install actually works (read once)

1. **Windows PE stage.** The USB boots a tiny Windows. Instead of the normal blue Setup wizard, our `pe.cmd` runs: it finds the one disk that matches our size rule, wipes it, creates two partitions, applies the image with DISM, writes the boot loader, and reboots. About 3 to 5 minutes on an SSD.
2. **Specialize pass.** First boot from the disk, before any user exists. The generator's scripts run here: remove leftover packages and features, set the taskbar and Start layout, theme, default-user registry tweaks.
3. **OOBE.** All the "Let's connect you to a network / sign in with Microsoft / choose privacy settings" screens are skipped because the answers are in the file.
4. **First logon.** Windows signs in to your account automatically once. Our three PowerShell scripts run in visible windows (perf, privacy, interface), Explorer restarts, and you are on the desktop. Total from USB boot to desktop is typically 8 to 12 minutes.

Everything the scripts print is saved to `C:\post-install-logs\` and `C:\Windows\Setup\Scripts\*.log`.

---

## 1. Import / Presets

**Set:** nothing, unless you are using the shortcut (Import `unattend/autounattend.example.xml`).

Do not click *Configure for minimal output* or *Just create one local user account* after importing; they reset the form.

---

## 2. Region and language settings

**Set:** *Install Windows using these language settings*

| Field | Value | Note |
|---|---|---|
| Windows display language | English (United States) | Must match the ISO from step 1. A mismatch fails the install. |
| Language 1 | English (United States) | **CHANGE** if you want another regional format (dates, currency). |
| Keyboard layout 1 | US | **CHANGE** to your physical keyboard. |
| Language 2 / 3 | leave empty | Each extra language adds a language pack and an input method that loads at logon. Add only what you type in. |
| Home location | your country | **CHANGE**. Only used to pre-fill the region in the PE script, which we override anyway (see section 3). |

**Why unattended:** every interactive screen here is an OOBE page you would otherwise click through.

---

## 3. Windows PE stage

This section decides which disk gets wiped, and it is where you paste `pe.cmd`. It has its own page: **[03-disk-script.md](03-disk-script.md)**. Do that now, then come back to section 4.

---

## 4. Activation

**Set:** empty.

**Why:** Pro re-activates from the digital license linked to your hardware as soon as it is online. Only fill this if you have a key that is not yet linked to this PC.

---

## 5. Processor architectures

**Set:** **x64** only.

**Why:** the ISO is x64. Ticking ARM64 too would add a second copy of every component block to the XML for no benefit.

---

## 6. Setup settings

| Option | Set | Why |
|---|---|---|
| Bypass Windows 11 requirements check | OFF | A Ryzen 5 3600 or anything newer, with fTPM or PTT enabled and UEFI, meets the requirements. Turn this ON only for older hardware. Enable **fTPM/PTT** and **Secure Boot** in the BIOS first; it takes one minute and avoids the bypass entirely. |
| Allow Windows 11 to be installed without internet connection | OFF | Our local account already skips the Microsoft-account wall; this option is only for PCs with no network at all. |
| Use a distribution share / configuration set ($OEM$) | OFF | Our PE script does not copy `$OEM$`. We do not need to drop files onto the target drive. |
| Hide any PowerShell windows during Windows Setup | OFF | Visible windows let you watch the three first-logon scripts and read any red error text. Nothing in our scripts asks for input, so there is no risk of a hidden prompt. |
| Keep sensitive files | OFF | The answer file is deleted from the installed system when Setup finishes. There is no password in ours, but there is no reason to keep it either. |
| Automatically start Narrator | OFF | |

---

## 7. Computer name

**Set:** *Choose a computer name yourself* → `MY-PC` in the example. **CHANGE** to whatever you like, 15 characters max, letters, digits and hyphens.

**Why:** the default is a random `DESKTOP-XXXXXXX`, which is what you see on your router and in every network dialog.

---

## 8. Time zone

**Set:** *Set your time zone explicitly* → `UTC` in the example. **CHANGE** to yours, for example `India Standard Time`. Run `tzutil /l` in any Windows command prompt to list the exact names.

**Why:** the automatic option uses the location service to guess. Section 26's privacy script denies location access, so the guess would fail and you would boot with the wrong clock, which breaks HTTPS and Windows Update until fixed.

---

## 9. User accounts

**Set:** *Let Windows Setup create the following local ("offline") accounts:*

| Account name | Display name | Password | Group |
|---|---|---|---|
| `User` | (empty) | (empty) | Administrators |

**CHANGE** the name. About the password:

- **Empty password** means Windows boots straight to the desktop with no lock screen, ever. Fine for a desktop in your own home. Anyone who can touch the PC can use it.
- If you type a password here, the file stores it in plain text (or Base64, see below) and Windows still auto-signs in **once** for the first-logon scripts. After that you get a normal lock screen.

**Why local instead of Microsoft account:** a local account skips four OOBE screens, never triggers OneDrive folder backup, never nags to "finish setting up", and never syncs settings or your clipboard to the cloud. You can still sign in to individual apps with a Microsoft account later if you want.

**First logon:** *Logon to the first administrator account created above*. **Why:** the first-logon scripts must run elevated, and this is the account they run as. The other options either leave you at a sign-in screen (scripts never run) or enable the hidden built-in Administrator account (bad practice).

**Obscure all account passwords with Base64:** OFF. It is not encryption, only obfuscation. Irrelevant with an empty password.

**Add a Microsoft account interactively / Add a local account interactively:** both OFF. Each one brings an OOBE screen back.

---

## 10. Password expiration

**Set:** *Passwords do not expire*.

**Why:** Windows' default forces a password change every 42 days on local accounts. Modern guidance (NIST) says forced rotation lowers security because people pick weaker, patterned passwords. Also removes a pop-up.

---

## 11. Account Lockout policy

**Set:** *Use default policy* (10 failed attempts in 10 minutes → locked for 10 minutes).

**Why:** it costs nothing and blocks brute-force attempts over RDP or SMB. Only disable if you regularly mistype your own password more than ten times.

---

## 12. File Explorer tweaks

| Option | Set | Why |
|---|---|---|
| Choose which files are hidden | **Show all files** | You will be looking in `C:\post-install-logs`, `AppData` and `ProgramData` when tuning this build. Hiding them just adds a Folder Options trip. |
| Always show file extensions | **ON** | `invoice.pdf.exe` shows as `invoice.pdf` with extensions hidden. This is a security setting as much as a convenience. |
| Use classic context (right-click) menu | **ON** | The Windows 11 menu is a separate WinUI process that takes a visible moment to appear and hides half the commands behind "Show more options". The classic menu is instant and complete. |
| Hide pop-up description for folder and desktop items | OFF | Tooltips on hover are harmless. |
| Open File Explorer to This PC | **ON** | "Home" shows recent and recommended files, which Explorer has to compute on every open. This PC is a static list of drives. |
| Show End task command in the taskbar | **ON** | Right-click a frozen app on the taskbar → End task. Saves opening Task Manager. |

---

## 13. Start menu and taskbar

| Option | Set | Why |
|---|---|---|
| Search box in the taskbar | **Hide** | The search box is also the surface for "search highlights" (daily web content). Hidden, plus the no-Bing setting below, means the search host does no network work. The perf script in step 4 then turns Windows search off altogether. If you delete those lines there, pressing the Windows key and typing still searches. |
| Icons to display in the taskbar | **Remove all icons** | The defaults pin Edge, Store, and Copilot. Edge and the Store are not even in this image. Pin your own apps after install. |
| Disable widgets | **ON** | Widgets is a WebView2 (Edge engine) process that runs at logon and polls news, weather and stocks. Removing it saves 100 to 200 MB of RAM and a chunk of network traffic. |
| Left-align the taskbar | **ON** | Start is at the fixed bottom-left corner, which you can hit without looking. Preference; turn OFF if you like centred. |
| Hide the Task view button | **ON** | Win+Tab does the same. One less thing on the taskbar. |
| Always show all tray icons | **ON** | Windows 11 hides new tray icons in an overflow so you do not see what is running in the background. Note: on Windows 11 this creates a small scheduled task that runs every few minutes to un-hide new icons. Turn OFF if you prefer zero background tasks and do not mind clicking the overflow arrow. |
| Do not show Bing results when searching | **ON** | Every keystroke in Start search otherwise goes to Bing. Turning it off makes Start search local-only and instant. |
| Windows 10 tiles | *Remove all tiles* | Ignored on Windows 11. Harmless. |
| Windows 11 pins | **Remove all pins** | Important: with *Use default pins*, Windows 11 keeps Start pins for apps we removed and shows broken "Install" tiles. Empty Start is the only clean option. |

---

## 14. System tweaks

Each row: what it does to CPU, RAM, boot time, or your patience.

| Option | Set | Why |
|---|---|---|
| Disable Windows Update | OFF | We want security updates. Section 26's perf script instead stops Windows Update from rebooting while you are logged on and from replacing your GPU driver, which are the two actual annoyances. |
| Disable User Account Control (UAC) | OFF | UAC is the line between "an app I ran" and "an app that owns the machine". Keep it. |
| Disable Smart App Control | **ON** | A fresh install runs SAC in evaluation mode and Windows decides later. It doesn't reliably turn itself off: it can go to enforcing about a week after install and then blocks unsigned DLLs ("Part of this app has been blocked", for example PostgreSQL's `libxml2.dll` from scoop). Most scoop and GitHub dev tools are unsigned. **Security trade, and it can't be undone:** once off, only a reinstall turns SAC back on. Leave OFF if you only run signed mainstream software. |
| Disable SmartScreen in Windows and Edge | **ON** | SmartScreen sends a hash of every new executable to Microsoft before letting it run and adds a delay plus a "Windows protected your PC" dialog for anything unsigned, which covers most indie tools and games. **This is a security trade:** Defender still scans the file; you lose the reputation check. Turn OFF if you install a lot of software from random sites. |
| Disable Fast Startup | **ON** | Fast Startup is a partial hibernation: shutdown writes the kernel to disk and boot reloads it. It causes stale driver state, breaks "turn it off and on again", and locks the NTFS volume so Linux dual-boot cannot write it. A cold boot from an SSD is under 15 seconds anyway. |
| Disable System Protection / System Restore | **ON** | Restore points are shadow copies that grow with every update and add write I/O. They rarely fix anything a reinstall would not. Our reinstall is 10 minutes from USB. Saves several GB. |
| Enable long paths | **ON** | Lets PowerShell, 7-Zip, git and others handle paths longer than 260 characters without errors. No cost. |
| Enable Remote Desktop | OFF | Opens a listening port. Enable later if you need it. |
| Harden ACLs | OFF | Removes write access to `C:\` root for normal users. Some old installers and game launchers write there and break. Not worth the support calls. |
| Delete hidden junction points | OFF | The `Documents and Settings` and similar junctions confuse humans but old software still follows them. Leave. |
| Allow execution of PowerShell script files | **ON** | Sets `RemoteSigned` so `.ps1` files you write locally run. Needed for the post-install scripts and for most tooling. |
| Do not update Last Access Time stamp | **ON** | Without this, every file *read* is also a metadata *write*. Turning it off reduces disk writes and directory-listing time on large folders. |
| Prevent Windows Update from rebooting | OFF | This option creates a scheduled task that keeps faking your active hours. The perf script uses the documented policy `NoAutoRebootWithLoggedOnUsers` instead, which achieves the same with no background task. |
| Turn off system sounds | **ON** | No ding on every dialog. |
| Disable app suggestions / Content Delivery Manager | **ON** | This is the mechanism that silently installs Candy Crush, TikTok and Spotify tiles on a clean install and shows "suggested" apps in Start. The single most important checkbox for keeping the image clean after a feature update. Side effect noted by the generator: the *Manage devices* button in Settings → Mobile devices disappears. |
| Prevent device encryption | **ON** | Windows 11 24H2 and later silently turn on BitLocker on the system drive at first sign-in. Every read and write then goes through AES; on a Ryzen 5 3600 class CPU that is a few percent of SSD throughput and CPU. Worse, the recovery key ends up nowhere useful on a local account, so a motherboard swap or a BIOS reset can lock you out of your own files. Encrypt later, on purpose, with a key you have backed up. |
| Hide Edge First Run Experience | **ON** | Edge is not in this image, so this is a no-op today. If a future update reinstalls Edge, this prevents its welcome wizard. |
| Disable Edge Startup Boost and Background mode | **ON** | Same reason. If Edge comes back, it will not keep a process resident at boot. |
| Make Edge uninstallable | OFF | Patches a system JSON file and the generator itself warns it breaks Windows Update. Edge is already absent. |
| Disable the Enhance Pointer Precision mouse setting | **ON** | Mouse acceleration off: the cursor moves exactly as far as your hand did. Standard for gaming. |
| Delete empty C:\Windows.old folder | **ON** | Housekeeping. |
| Disable automatic sign-on of last user after a restart | **ON** | Stops the "Someone else is still using this PC" warning at restart. |
| Disable Windows Platform Binary Table (WPBT) execution | **ON** | WPBT lets the motherboard firmware inject an executable into every Windows install at boot. ASUS uses it for Armoury Crate, Lenovo for its updaters. This blocks all of it. |
| Prevent download and installation of applications associated with certain hardware devices | **ON** | Stops Windows from auto-installing the "companion app" for monitors, mice and printers (the LG monitor incident). Drivers still install; the bloat app does not. |
| Audit process creation events | OFF | Writes a Security-log event for every process start. Useful for forensics, costs disk and CPU on every launch. |

---

## 15. Visual effects

**Set:** *Use custom settings*, then:

| Keep ON | Why |
|---|---|
| Smooth edges of screen fonts | ClearType. Without it text is jagged. Zero performance cost on any GPU made this century. |
| Show thumbnails instead of icons | Image and video previews in Explorer. Cached after first view. |
| Show window contents while dragging | Otherwise you drag an outline, which looks broken. Trivial cost with GPU composition. |
| Show translucent selection rectangle | The blue rubber-band box. Trivial. |
| Use drop shadows for icon labels on the desktop | Desktop icon text readable on any wallpaper. Trivial. |
| Fade or slide menus into view | Very short fade. Turn OFF for instant menus. |
| Fade or slide ToolTips into view | Same. |
| Fade out menu items after clicking | Same. |

| Turn OFF | Why |
|---|---|
| Animate controls and elements inside windows | |
| Animate windows when minimizing and maximizing | The minimize/maximize/open/close zoom is about 200 ms of waiting on every window action. Off, windows appear instantly. |
| Animations in the taskbar | |
| Enable Peek | The hover-to-see-desktop feature. Rarely used, keeps thumbnails live. |
| Save taskbar thumbnail previews | Caches live previews of every open window. Memory for a feature you glance at. |
| Show shadows under mouse pointer | |
| Show shadows under windows | The Windows 11 window shadow is a blur pass composited every frame the window moves. |
| Slide open combo boxes | |
| Smooth-scroll list boxes | |

**Why this mix:** DWM composites the desktop on the GPU regardless, so "best performance" mode gains almost nothing in frame rate. What animations cost is *latency*: every window action waits for the animation to finish. Removing the animations while keeping font smoothing and thumbnails gives an instant desktop that still looks normal. The interface script in section 26 sets the same values again in the registry so they survive a theme change.

---

## 16. Desktop icons

**Set:** *Delete Edge shortcut on desktop* ON. *Show these desktop icons*: **Recycle bin, This PC, User's Files**.

**Why:** the default desktop has Edge and the Recycle Bin. This PC and your user folder are the two places you actually navigate to.

---

## 17. Folders on Start

**Set:** *Show these folders*: **Downloads, Settings**.

**Why:** they appear as small icons next to the power button. Downloads and Settings are the two you open most. Each extra one is clutter.

---

## 18. VM hosts (Core isolation)

**Set:** *Disable core isolation*.

**Why:** memory integrity (HVCI) runs the kernel under a hypervisor so a driver exploit cannot patch it. It costs roughly 3 to 7 % in CPU-bound games on a Ryzen 5 3600 class CPU, which is the largest single CPU-side gain in this whole file. This option writes the two DeviceGuard registry values during the **specialize** pass, before OOBE and before any user exists, so the hypervisor is never started on this install. It is the same as Windows Security → Device security → Core isolation → Memory integrity → Off, and can be turned back on there at any time (one reboot). **Security trade:** you lose kernel-level exploit mitigation. The current Vanguard, Ricochet, Javelin and FACEIT builds do not require memory integrity; they require Secure Boot and TPM 2.0, which stay on. Choose *Keep core isolation enabled* if you want the protection or if you run WSL2, Windows Sandbox or Hyper-V, which need the hypervisor.

---

## 19. VM guests

**Set:** none.

**Why:** these install guest tools for VirtualBox, VMware, QEMU or Parallels. This file targets bare metal. If you test the file in a VM first (recommended, see [06-install-and-verify.md](06-install-and-verify.md)), tick the matching one for that test build only.

---

## 20. WLAN / Wi-Fi setup

**Set:** *Skip Wi-Fi configuration*.

**Why:** the desktop is on Ethernet. The Wi-Fi OOBE screen is skipped and no wireless profile is written. If your PC is Wi-Fi only, choose *Configure Wi-Fi using these settings* and enter SSID and password; the file will contain the password in plain text, so keep the USB stick private.

---

## 21. Express settings

**Set:** *Disable all*.

**Why:** this answers the OOBE privacy page (location, Find my device, diagnostic data, inking, tailored experiences, advertising ID) with "no" to all six in one go. The privacy script enforces the same via policy so they cannot be flipped back by an update.

---

## 22. Lock key settings

**Set:** *Use default lock key states and behaviors*.

---

## 23. Sticky keys

**Set:** *Disable Sticky keys altogether*.

**Why:** pressing Shift five times in a game otherwise pops a dialog and steals focus.

---

## 24. Personalization settings

**Colors:** *Use custom color theme*

| Field | Value | Why |
|---|---|---|
| Taskbar and Start | Dark | Preference. |
| Apps | Dark | Preference. |
| Accent color | `#33d17a` (green) | **CHANGE** freely. |
| Show accent on Start and taskbar | OFF | |
| Show accent on title bars | OFF | |
| Windows and surfaces appear translucent | **OFF** | Transparency is a real-time blur behind the taskbar, Start and every flyout, rendered by the GPU every frame those surfaces are visible. Off is the single biggest desktop GPU saving in this file, and it makes text on the taskbar easier to read. |

**Desktop wallpaper:** *Use a solid color background* → `#000000`.

**Why:** no image to decode at logon, no Spotlight downloads, and pure black on an OLED or VA panel is literally pixels off. Set your own image afterwards if you like; this just stops Windows fetching one.

**Lock screen image:** *Use default lock screen image*. The interface script turns off Spotlight rotation and the "fun facts" overlay, so the lock screen stays static.

---

## 25. Remove bloatware

Step 1 already left almost all of these out of the ISO. Ticking them here is a **safety net**: if a feature update or a stray Store call brings one back, the removal script runs again on the next install. Ticking something that is not installed costs nothing. A few of these are not Store apps but Windows *features* or *capabilities*, and those are only removable here.

**Tick everything except** the three in the second table.

| Tick | What it is and why remove |
|---|---|
| 3D Viewer, Paint 3D, Mixed Reality | Leftovers from the 2017 "3D" push. Mixed Reality installs a portal service. |
| Bing Search, Cortana, Copilot, Recall | Cloud search and assistants. Copilot registers a background task; Recall (Copilot+ PCs only) screenshots your screen continuously. |
| Calculator, Clock, Camera, Photos, Paint, Snipping Tool, Sticky Notes, Voice Recorder | Store apps that all register background tasks and Start pins. Reinstall any you want with winget later. **Note:** removing Photos leaves no image viewer, because the classic Windows Photo Viewer is gone from Windows 11. Install IrfanView afterwards, or untick Photos. |
| Clipchamp, Movies & TV, Windows Media Player (modern and classic), Solitaire Collection, Xbox Apps, Game Assist | Media and gaming apps. Xbox Apps includes the Game Bar overlay that hooks every full-screen game. Steam, GOG and the Xbox app can be installed later if you want Game Pass. |
| Dev Home, Feedback Hub, Get Help, Tips, Quick Assist, Steps Recorder | Microsoft support and telemetry apps. Quick Assist allows remote control of the PC and is the tool used in most "Microsoft support" scams. |
| Facial recognition (Windows Hello), Handwriting, Speech, Math Input Panel | Input methods you do not have hardware for. Speech alone is several hundred MB of language models. |
| Internet Explorer, WordPad, PowerShell 2.0, PowerShell ISE | Legacy features. PowerShell 2.0 is an old engine used for downgrade attacks; PowerShell 5.1 stays. |
| Mail and Calendar, Outlook for Windows, Office 365, OneNote, OneDrive, OneSync, People, To Do, Teams, Skype, Family, Wallet, Your Phone | Microsoft-account services. OneDrive alone installs a startup entry, a shell extension in every Explorer window, and a sync engine. OneSync is the background service that keeps mail and contacts in sync for apps we are removing. |
| Maps, Weather, News | Each keeps a background updater. |
| Microsoft Store | Removing the Store is the controversial one. Reason: without it nothing can silently install apps, and the Store's own updater service stops running. Cost: you install everything with winget or downloads. **Reinstalling the Store later is fiddly**; untick this if you know you want Store apps. |
| Power Automate | RPA tool nobody asked for. |
| Remote Desktop Client | The *modern* RDP client Store app. The classic `mstsc.exe` stays. |
| Windows Terminal | The classic console remains for cmd and PowerShell. Untick if you like Terminal. |

| Leave UNTICKED | Why |
|---|---|
| Media Features | This is the Media Foundation framework, not an app. Removing it breaks video playback in browsers, game cutscenes, and any app that decodes audio or video. |
| Notepad (modern) | Step 1 already left Notepad out of the ISO. Ticking this as well changes nothing, but if you decided to keep Notepad in step 1, leave it unticked here or you remove it again. |
| OpenSSH Client | 5 MB, no background process, and `ssh` from a terminal is useful. |

---

## 26. Run custom scripts

This is where you paste the three first-logon scripts. It has its own page: **[04-first-logon-scripts.md](04-first-logon-scripts.md)**. Do that now, then come back to section 27.

---

## 27. AppLocker

**Set:** *Do not configure AppLocker policy*.

**Why:** application allow-listing is for managed corporate machines. On a personal PC it blocks every installer you download until you write rules.

---

## 28. XML markup for more components

**Set:** empty.

---

## 29. Download settings

**Set:** *Use filename notautounattend.xml* **OFF**.

**Why:** Windows Setup only picks up the file automatically when it is named `autounattend.xml`. The "not" variant is for people who want to run Setup from inside Windows with a manual command line.

**Submit form → Download .xml file.** Save it as `autounattend.xml` next to your ISO. (The site's "wrapped in .iso" option is for VMs; we do not need it.)

**Before you flash, open the file in an editor and search for these to confirm your edits took:** your user name, your computer name, your time zone, the two `expected =` lines (your size range, not `0`), and `GeoID`.

---

Next: [05-flash-usb.md](05-flash-usb.md).
