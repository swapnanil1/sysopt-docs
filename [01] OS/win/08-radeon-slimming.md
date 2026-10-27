# Radeon Software: retain tuning, overlay and recording

Last updated: 2026-10-27. Update this guide as driver packaging and verified behavior change.

## Jump to a step

1. [Packages](#1-packages)
2. [Scheduled Tasks](#2-scheduled-tasks)
3. [Display Driver Components](#3-display-driver-components)
4. [Apply the selections](#apply-the-selections)
5. [Reduce background work](#reduce-active-work-while-preserving-features)
6. [Verify the installation](#installation-verification-and-next-update)

[Evidence and sources](#evidence-review-what-to-trim-first) · [Unresolved dependencies](#unresolved-dependencies)

## Intended configuration

This guide trims a Windows Radeon installation while retaining performance tuning/overclocking, the in-game overlay, and ReLive/Record & Stream recording.

The default profile assumes:

- Desktop with PC-connected analog audio.
- No AMD-integrated camera or NPU.
- No GPU USB-C device, AMD Link or AMD VR streaming.
- Optional usage reporting and Noise Suppression off.

Select the optional entries below if you use those features. Laptop and APU users must check platform audio/camera requirements before copying the desktop omissions.

A 3.5 mm jack on the **PC** uses its sound device; a 3.5 mm jack on a **monitor** may receive audio through HDMI/DisplayPort and require the AMD HDMI Audio Driver. Keep the motherboard/sound-device driver separately; trimming Radeon packages is not a substitute for installing it.

The recommendations are based on a source review of RadeonSoftwareSlimmer and the linked documentation. This selection profile has **not been validated on a Windows installation**; use the verification steps at the end.

Choose **Default/Full** in AMD's installer after making the selective changes. AMD's **Minimal** option omits advanced tuning and recording; Driver Only omits the Radeon interface. See [AMD's installation guide](https://www.amd.com/en/resources/support-articles/faqs/RSX2-INSTALL.html).

## Selection workflow

In each **Pre Install** tab:

1. Click **Select None**.
2. Select every baseline item listed below.
3. Add the optional items for your hardware/features.

The empty checkboxes below are a reading checklist: **baseline entries should be checked in Slimmer**. They do not mean “disable.”

Finish all three tabs before clicking **Modify Installer**.

- **Packages / Display Driver Components:** checked **Keep** retains the item; unchecked requests removal.
- **Scheduled Tasks:** checked **Enabled** enables the task; unchecked requests disabling, not removal of its application.
- The baseline preserves the requested Radeon interface, tuning, overlay and recording with conservative choices where dependencies are unclear. It is not a proven absolute minimum.
- Names vary between driver releases. If your installer adds an unfamiliar entry, reselect it pending review rather than treating its omission here as permission to remove it. Scroll through the full list, including entries below the visible area.

## 1. Packages

Click **Select None**, then check **Keep** for the items below.

### Select these baseline packages

- [ ] **AMD Display Driver**

  Core GPU driver.

- [ ] **AMD Settings**

  Radeon interface and access to settings/tuning.

- [ ] **AMD DVR64**

  Overlay, recording, streaming and related host functionality. Screen/game recording does not require a webcam or monitor speakers.

- [ ] **Microsoft Visual C++ Redistributable entries**

  Runtime dependencies. Select all entries offered by this installer.

- [ ] **Branding64**

  Retained conservatively because the full current dependency role is unverified.

- [ ] **AMD High Definition Audio Controller**

  Retain the supporting audio controller until hardware dependencies are confirmed.

- [ ] **AMD Streaming Audio Filter Driver**

  Temporary conservative keep for recording verification, not a proven ordinary-recording dependency. AMD explicitly documents its virtual audio device for Noise Suppression; see the research notes below.

### Select these for the hardware/features you use

#### HDMI / DisplayPort audio

**Select:** **AMD HDMI Audio Driver**

Leave unchecked for PC-connected analog audio only. Select for GPU audio, including a monitor headphone jack; retain if unsure.

#### Legacy AMD VR streaming

**Select:** **AMD WVR64**

Leave unchecked when unused. The project identifies this as AMD GO OpenVR support.

#### Matching GPU USB-C hardware

**Select:** **AMD Navi UCSI Driver**

Leave unchecked if matching GPU USB-C hardware is absent; retain if unsure.

#### AMD-integrated camera hardware

**Select:** **AMD Camera Capture Device**, **AMD ISP Bridge Device**, and the matching **Camera RGB/IR sensor** entries

Leave unchecked without matching integrated camera hardware. These are not a generic requirement for every USB webcam; retain if unsure.

#### An AMD NPU

**Select:** **AMD Kipudrv Device for MCDM/WDF** entries matching the platform

Leave unchecked on a system without an AMD NPU. Check CPU/platform specifications; retain if unsure.

#### AMD ACP/platform audio

**Select:**

- **AMD ACP AFD HPD User Service**
- **AMD ACP BT Audio Filter Driver**
- **AMD ACP BT LE Audio Device**
- **AMD ACP BUS2**
- **AMD ACP USB Audio Filter Driver**
- **AMD Audio CoProcessor Bus Driver**
- **AMD Audio Filter Driver**

Leave unchecked only when matching ACP devices are absent. A PC analog jack alone does not establish this; retain on unverified platforms.

#### SoundWire/I2S platform audio

**Select:**

- **AMD SoundWire Controller Driver**
- **AMD SoundWire Streaming Driver**
- **I2S Audio Driver**

Leave unchecked when matching SoundWire/I2S devices are absent; retain on unverified platforms.

#### Participation in AMD's optional usage-reporting program

**Select:** **AMD User Experience Program Installer**

Leave unchecked for the intended setup.

**Default omissions:** leave UEP, WVR64, the unused camera/ISP/sensor group, NPU drivers, unused UCSI, and unused ACP/SoundWire/I2S packages unchecked under the assumptions above. Leave HDMI Audio unchecked only when no output uses GPU audio. These omissions do not remove ordinary screen recording: keep **AMD DVR64**. For an unfamiliar audio device, check Device Manager and its hardware IDs before omitting its driver.

The DVR64/WVR64 mapping comes from the project's older [installer-entry documentation](https://github.com/GSDragoon/RadeonSoftwareSlimmer/wiki/Installer-Entries), which acknowledges uncertainty. Treat it as guidance, not a dependency guarantee for every release. AMD describes UEP in its [User Experience Program documentation](https://www.amd.com/en/legal/privacy/user-experience-program.html).

## 2. Scheduled Tasks

Click **Select None**, then check **Enabled** for the items below.

### Select these baseline tasks

- [ ] **AMD COMPUTE**

  Keep during installation; its exact trigger/install role is unverified.

- [ ] **AMD RELAUNCHER**

  Keep during installation; its exact trigger/install role is unverified.

- [ ] **AMD UWP LAUNCHER**

  Preserve application launch behavior initially.

- [ ] **AMDScoSupportTypeUpdate**

  Retain pending review; insufficient evidence for disabling it.

- [ ] **EnableWindowsDriverSearch**

  Retain pending review; no demonstrated performance problem.

- [ ] **ModifyLinkUpdate**

  Retain pending review; current behavior is unverified.

These are conservative selections, not claims that all six tasks are required for recording or tuning.

### Select these only for the corresponding feature

#### AMD's automatic update task

**Select:** **AMD Updater** (`/AUTOUPDATEIN`)

Leave unchecked and install driver updates manually. This does not guarantee every other AMD update path is disabled.

#### Legacy AMD Link updates

**Select:** **AMD Link Driver** (`-AMDLinkUpdate`)

Leave unchecked if AMD Link is unused.

#### AMD User Experience Program participation

**Select:** **AMDInstallLauncher** (`/InstallAUEP`) and **AMDInstallUEP**

Leave both unchecked for the intended setup, alongside the UEP package.

Do not infer that tasks sharing `/AUTOUPDATEIN` have identical triggers or purposes. The project's [task documentation](https://github.com/GSDragoon/RadeonSoftwareSlimmer/wiki/Scheduled-Tasks) marks several roles as uncertain. Check the command and effective state again after installation.

If **StartCN** or **StartDVR** appear in this tab or Post Install, **select/keep them enabled** for Radeon Software and overlay/recording host functionality. Retain Radeon host processes and **AMD External Events Utility** for the initial configuration. The project associates `AMDRSServ.exe` with overlay/recording and `amdow.exe` with desktop capture; see its [host-service notes](https://github.com/GSDragoon/RadeonSoftwareSlimmer/wiki/Host-Services).

### Task names and the shared executable are different things

`AMDInstallLauncher` is the name of one scheduled task. In the reviewed task list, its action is:

- **Program:** InstallManagerApp.exe
- **Argument:** `/InstallAUEP`
- **Folder:** C:\Program Files\AMD\CIM\Bin64

Other tasks invoke the same `InstallManagerApp.exe` with different arguments, such as `/AUTOUPDATEIN` or `/LaunchUWPApp`. They do not invoke the `AMDInstallLauncher` task simply because they share its executable.

Unchecking **AMDInstallLauncher** changes that task's XML `Enabled` value to `false`. It does **not** delete `InstallManagerApp.exe`, uninstall AMD Install Manager, or disable the other tasks. Keep the shared install manager if it is offered as a separate package; disabling the UEP task does not require removing it.

This distinction is verified in Slimmer's `ScheduledTaskXmlListModel.SetScheduledTaskStatusAndUnhide`: it changes only `Enabled` and `Hidden` before saving the task XML. `PreInstallViewModel.ModifyInstaller` handles package removals separately. There are no task-specific dependency comments establishing how AMD installs the shared executable. Slimmer's source does not contain AMD's installer implementation, so it cannot prove that a particular trimmed package will install that executable successfully. After installation, verify that InstallManagerApp.exe in C:\Program Files\AMD\CIM\Bin64 exists and that retained tasks have valid actions.

## 3. Display Driver Components

Click **Select None**, then check **Keep** for the items below.

### Select these baseline components

- [ ] **AMD-OpenCL User Mode Driver** (`amdocl`)

  Compute compatibility. Removing installed runtime files is not a demonstrated CPU optimization.

- [ ] **AMD-OpenGL User Mode Driver** (`amdogl`)

  Application/game compatibility.

- [ ] **AMD-Vulkan User Mode Driver** (`amdvlk`)

  Application/game/emulator compatibility.

- [ ] **AMD-Windows Support Components** (`amdwin`)

  Windows integration.

- [ ] **AMD PCI Bridge Device Extension** (`amdpcibridge`)

  Platform integration.

- [ ] **AMD Crash Defender** (`amdfendr`)

  Stability/recovery support, particularly relevant when tuning.

- [ ] **High Definition Audio Controller Extension** (`amdafd`)

  Retain initially alongside the audio stack until hardware is confirmed.

### Select these for optional features

#### AMD Noise Suppression

**Select:** **AMD-Dynamic Audio Noise Suppression** (`amdfdans`); also retain **AMD Streaming Audio Filter Driver** in Packages

Leave `amdfdans` unchecked if unused.

#### Legacy AMD Link/controller forwarding

**Select:** **AMD Controller Emulation** (`amdxe`)

Leave unchecked if unused; verify this mapping for the driver release.

**AMD Crash Defender is unrelated to Microsoft Defender Antivirus.** AMD describes it as a stability feature for recovery from certain hangs/crashes. See [AMD's feature announcement](https://www.amd.com/en/newsroom/press-releases/2021-4-20-latest-amd-radeon-software-release-expands-remote-.html). Historical controller-emulation and audio mappings are in the project's [services and drivers notes](https://github.com/GSDragoon/RadeonSoftwareSlimmer/wiki/System-Services-and-Drivers).

## Apply the selections

1. Review all three tabs: baseline entries selected, desired optional features selected, and unresolved hardware entries retained.
2. Click **Modify Installer** and review the Logging tab for errors.
3. Click **Run Installer** and choose **Default/Full** to retain tuning and recording. Leave the optional **AI Bundle/AMD Chat** unselected when unused; turn automatic updates off if managing updates manually.
4. Reboot and run the verification below before removing any further components.

## Reduce active work while preserving features

Removing unused driver files can reduce installation size without materially reducing CPU or RAM use. Measure active background work rather than judging performance by package count.

- Keep manual recording available.
- Turn **Instant Replay**, **Instant GIF**, and **In-Game Replay** off when not wanted. Instant Replay continuously captures gameplay while enabled.
- Leave **Enhanced Filtering** off initially; AMD notes it can affect gaming performance.
- Keep overlay support installed and show the overlay when needed. Stop performance logging when not benchmarking.
- Try a **1–2 second metrics sampling interval** instead of 0.25 seconds when slower updates are acceptable. This reduces requested sampling frequency; the CPU benefit must be measured. AMD documents selectable metrics and a 0.25–5 second range in its [metrics guide](https://www.amd.com/en/resources/support-articles/faqs/DH3-038.html). Hiding the overlay alone does not prove logging or polling has stopped.
- Decline UEP participation and verify its installer tasks remain disabled.

These recording controls are described in [AMD's recording settings guide](https://www.amd.com/en/resources/support-articles/faqs/DH3-023.html). No FPS improvement is assumed or measured yet.

## Installation verification and next update

1. Record the official AMD package version and the exact Slimmer choices.
2. Install using Default/Full and reboot.
3. Check Device Manager for newly missing drivers or device errors.
4. Verify Radeon tuning controls, then check the intended tuning profile after reboot.
5. Test the in-game overlay and its hotkeys.
6. Record a short clip and play it back, checking game audio and microphone audio if used.
7. Verify normal audio output and FreeSync/display behavior if used.
8. Inspect installed packages, scheduled tasks and running processes. Measure idle CPU/RAM and repeat a consistent game benchmark before attributing improvements to slimming.

Keep a local record of the driver version, selected components, verification results and any measured CPU/RAM/frame-time changes. Recheck the selections with each driver update; do not treat a completed installation as proof that every retained feature works.

## What Slimmer changes

The local implementation does not validate feature dependencies before removal:

- `PackageListModel.RemovePackage` removes an entry from AMD's JSON installer manifests; it does not itself delete the package payload.
- `ScheduledTaskXmlListModel.SetScheduledTaskStatusAndUnhide` changes the task XML's enabled state and makes the task visible.
- `DisplayComponentModel.Remove` moves a deselected component directory into the installer's `RSS_Backup` area.

These operations alter the extracted installer. A selectable checkbox does not establish that a component is unnecessary. The project's [installer notes](https://github.com/GSDragoon/RadeonSoftwareSlimmer/wiki/Installer-Packages) also describe nested AMD installers that can limit the effect of manifest changes. Verify the installed result rather than assuming every unchecked entry stayed absent.

Keep an untouched official AMD installer for recovery. Do not edit signed driver INF files or disable signature enforcement/Secure Boot to make a trimmed package install.

## Evidence review: what to trim first

Reviewed against AMD documentation and the Slimmer project on 2026-10-27. **Documented** means the source establishes the feature's role; it does not mean AMD supports every third-party package-removal combination. **Historical** means the project documented an older implementation. **Unresolved** means no reliable current dependency explanation was found.

### UEP package and its two install tasks

**Documented optional participation.** Leave unselected and decline participation. AMD describes collection/transmission of usage and hardware information. [AMD UEP](https://www.amd.com/en/legal/privacy/user-experience-program.html)

**Resource effect:** Avoids optional reporting work when it would otherwise be active. No measured CPU/RAM saving; declining consent may already prevent participation.

### AI Bundle / AMD Chat, if offered

**Documented optional applications.** Skip when this Windows installation is for gaming and capture. Keep core graphics drivers and graphics API runtimes. [AI Bundle announcement](https://www.amd.com/en/blogs/2026/amd-software-adrenalin-edition-ai-bundle-ai-made-si.html), [26.1.1 release notes](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-1-1.html)

**Resource effect:** Avoids extra downloads, environments and application storage. Idle CPU/RAM savings depend on whether the apps would actually run.

### AMD Link task and `amdxe`

**AMD Link is end-of-life.** Leave these legacy feature entries unselected for this profile. End-of-life does not prove that every similarly named component lacks shared dependencies. [AMD end-of-life notice](https://www.amd.com/en/resources/support-articles/faqs/PA-325.html), [24.1.1 release notes](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-24-1-1.html)

**Resource effect:** Removes unwanted legacy functionality where those entries are still used. No measured saving.

### WVR64

**Historical project finding:** AMD GO OpenVR support; the maintainer reported repeated OpenVR settings-file accesses even without a VR device. Leave unchecked when unused, but do not present that old polling behavior as verified in current drivers. [Installer entries](https://github.com/GSDragoon/RadeonSoftwareSlimmer/wiki/Installer-Entries)

**Resource effect:** Potential background file-access reduction on affected older builds; current effect unverified.

### Noise Suppression / `amdfdans`

**Documented CPU/GPU processing feature.** Leave unchecked when unused. [AMD Noise Suppression](https://www.amd.com/en/products/software/adrenalin/amd-noise-suppression.html)

**Resource effect:** Avoids processing when the feature would otherwise be active. Removing an already-disabled feature is not a demonstrated FPS improvement.

### AMD Streaming Audio Filter Driver

**Documented virtual-device use for Noise Suppression.** AMD instructs users to select AMD Streaming Audio Device. No reliable source found establishing that this separate package is mandatory for ordinary ReLive game/mic capture. Keep for the first capture test; it is a candidate for a separate removal test when Noise Suppression and legacy Link audio are unused. [AMD Noise Suppression](https://www.amd.com/en/products/software/adrenalin/amd-noise-suppression.html)

**Resource effect:** Removes unused virtual audio support if the removal test passes; current steady-state overhead is unknown.

### Branding64

**Unresolved full role.** The project labels its purpose tentatively. AMD names it in installer-repair guidance, which establishes installer involvement, not a continuous background workload. Keep for now. [AMD error 1604](https://www.amd.com/en/resources/support-articles/faqs/gpu-kb1604.html)

**Resource effect:** No evidence of worthwhile CPU/RAM saving from removal.

### Camera, NPU, ACP, SoundWire and UCSI packages for absent hardware

Omit only after confirming no matching device. These are hardware-support selections, not blanket performance tweaks.

**Resource effect:** Mainly package/staging reduction; a driver for absent hardware is not evidence of a running workload.

### OpenGL, Vulkan, OpenCL and Windows/PCI support

Keep for compatibility.

**Resource effect:** No evidence that deleting unused API files reduces idle CPU use.

## Automatic updates: use AMD's setting first

AMD documents an **Automatically keep AMD Software up to date** option with the Install Manager introduced in 25.3.1. Turn automatic updates off if installing updates manually. Preserve the manager so manual installation and servicing remain available. This is a better-supported control than assuming `/AUTOUPDATEIN` means every task using it is safe to disable during installation. [AMD 25.3.1 release notes](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-25-3-1.html)

That newer Install Manager documentation does not establish that its packaging is identical to the older `CIM\Bin64\InstallManagerApp.exe` task helper. The exact package responsible for that executable remains unverified.

## Unresolved dependencies

No reliable current source found explains the full behavior and dependency chain of `AMDScoSupportTypeUpdate`, `EnableWindowsDriverSearch`, `ModifyLinkUpdate`, or the separate `AMD COMPUTE` and `AMD RELAUNCHER` triggers. The project's task notes are from 2021 and contain guesses. The local test manifests contain dummy package entries, not an inventory of AMD's real installer. Keep these uncertain tasks during the first installation; this is caution, not evidence that they are required for gameplay.

To resolve them for a particular driver, inspect the extracted `Config/*.xml`, `Config/InstallManifest.json`, `Bin64/cccmanifest_64.json`, and installer logs. The task XML provides triggers and execution conditions that the Slimmer table does not show. Determining package ownership of the executable may also require inspecting the MSI file tables. Package descriptions and command names alone are insufficient.

After installation, these PowerShell commands inspect task actions/triggers and the shared executable without changing settings:

```powershell
$names = 'AMD|Radeon|StartCN|StartDVR'
$fields = @(
    'TaskPath', 'TaskName', 'State',
    'Actions', 'Triggers', 'Settings'
)
Get-ScheduledTask | Where-Object {
    $_.TaskName -match $names -or
    ($_.Actions.Execute -join ';') -match 'AMD|Radeon'
} | Select-Object -Property $fields |
    ConvertTo-Json -Depth 8

$folder = 'C:\Program Files\AMD\CIM\Bin64'
Test-Path (Join-Path $folder 'InstallManagerApp.exe')
```

Compare task history, process CPU time, memory and disk activity with one change at a time. An enabled task may run only at setup or logon; its mere existence does not imply continuous resource consumption.
