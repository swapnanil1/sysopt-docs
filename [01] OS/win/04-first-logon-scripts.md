# Step 4: The first-logon scripts (form section 26, Run custom scripts)

## What this step is

This is part of step 2. You paste the three files from [scripts/](scripts/) into section 26 of the generator form and the generator copies them into your `autounattend.xml`. Setup runs them automatically at the first logon.

The scripts assume a desktop with at least a Ryzen 5 3600 class CPU and 16 GB of RAM. Nothing in them breaks on faster hardware.

The standalone files are the same text as the copies inside [unattend/autounattend.example.xml](unattend/autounattend.example.xml). To change one, edit the standalone file and paste it into the form again.

Read the three tables before you paste. A few lines turn off things you might use, and those are marked **CHANGE**.

**System scripts:** none. **DefaultUser scripts:** none. **UserOnce scripts:** none.

**Why:** everything we need is per-user registry or machine policy that can be applied once an admin is logged on, so FirstLogon is the right stage. It also means the scripts run with a visible window you can read.

**FirstLogon scripts:** paste the three files, each as **.ps1**, in this order. Order matters only in that the last script to set a value wins.

## FirstLogon script 1: `scripts/01-perf.ps1`

Only documented policies, services listed as safe to disable in Microsoft's own IoT/VDI guidance, and scheduled tasks. Every block is reversible by deleting the policy value or setting the service back to Manual, except Smart App Control, which can't be turned back on.

| Block | Does | Why |
|---|---|---|
| Background apps = force deny | Policy that stops Store apps running when not open | Store apps are gone, but this also stops any that come back from waking for notifications. |
| Widgets policy off | Stops the Widgets/WebView2 host even if the taskbar button is re-enabled | RAM. |
| Game DVR off | No background game recording encoder | The capture service otherwise attaches to every full-screen game. Measurable frame-time win. |
| Delivery Optimization = HTTP only | No peer-to-peer update sharing | Stops your PC uploading Windows Update bits to strangers and stops the DO service doing bandwidth probing. |
| Consumer features off | Policy version of section 14's app-suggestion setting | Belt and braces; policies survive feature updates. |
| Search box web suggestions off | Same as section 13, as policy | Same. |
| Start search without WebView2 | Per-app WebView2 policy that points `SearchHost.exe` at a folder that doesn't exist | Only matters once the WebView2 runtime is installed. Search then starts a set of `msedgewebview2.exe` processes at logon and keeps them open. With the policy it uses its built-in window, which saves about 90 MB. Other apps still use the runtime. |
| Maintenance does not wake the PC | | Your PC stays asleep at 3 a.m. |
| Windows Update excludes drivers | | Windows Update otherwise replaces the GPU driver you installed with an older WHQL one, which breaks the vendor's control panel (AMD Adrenalin is the usual victim). Update GPU and chipset drivers from the vendor yourself. |
| No auto-reboot with logged-on users | | Updates install but wait for *you* to reboot. |
| Explorer folder type = NotSpecified | Explorer stops guessing "this looks like a Pictures folder" | Large folders open faster; no more surprise column layouts. |
| Search index limited to the Start menu | Indexer only crawls `Start Menu\Programs` and never `C:\Users` | Only matters if you keep Windows search (see "Windows search off" below). Start-menu app search then stays instant and the indexer stops churning your disk after every file change. If you rely on Explorer content search, remove these two lines. |
| Indexer respects power mode | | |
| MMCSS SystemResponsiveness 10 | Reserve 10 % CPU for background instead of 20 % | Documented Microsoft value; gives foreground multimedia (games, audio) a larger share. |
| Program Compatibility Assistant off | | Stops the "this app might not have installed correctly" dialog and the process that watches every install for it. |
| Telemetry = Required | Policy value 1 | The lowest level Pro honours. |
| Services disabled | MapsBroker, RetailDemo, workfolderssvc, lfsvc (Geolocation), **Spooler, LanmanServer, four Xbox services**, WSAIFabricSvc, DiagTrack | Services that start automatically and are on Microsoft's safe-to-disable list, plus the last two. Manual (trigger-start) services cost nothing while idle, so the script deliberately does not touch them. **CHANGE:** remove `Spooler` if you print (also needed for Print to PDF). Remove `LanmanServer` if this PC shares folders to other machines. Remove the four Xbox lines if you use Game Pass or the Xbox app. `WSAIFabricSvc` (Windows AI Fabric) isn't from that list. It hosts on-device Copilot+ models and starts on boot even without an NPU. Remove the line on a Copilot+ PC. `DiagTrack` is the telemetry service. It runs all the time and holds around 30 MB. Microsoft only supports disabling it on fixed-function devices, and the Feedback Hub and Insider builds need it, so remove the line if you use either. |
| Storage Service on Manual | `StorSvc` start type Automatic to Manual | It is trigger-started, so Windows still starts it when something needs it. A few MB while idle. |
| SysMain off | Stops and disables `SysMain` (Superfetch) | No prefetching and none of its background disk activity. Memory compression goes with it, because SysMain is what runs it. With 16 GB or more that rarely matters. When RAM does run out, Windows pages to disk sooner. **CHANGE:** delete the two lines on a PC with less RAM. |
| Scheduled tasks disabled | CEIP Consolidator and UsbCeip, DiskDiagnostic collector, PcaPatchDb, Power Efficiency AnalyzeSystem, Flighting UsageDataReporting | Pure telemetry collectors that run on idle. |
| Hibernate off | Deletes `hiberfil.sys` | Frees a file as big as your RAM (16 GB or more) on the SSD. Sleep still works. Section 14 disabled Fast Startup, which was the only other thing using it. |
| Reserved storage off | | Windows otherwise holds ~7 GB back "for updates". On a small system drive you want it back. |
| Memory integrity / VBS off | Same two DeviceGuard values as section 18 | Section 18 already did this in the specialize pass, before OOBE. It is repeated here on purpose: the three scripts are written to be complete on their own, so you can run them by hand on a Windows 11 install that did not come from this ISO or this answer file. The report block at the end prints the VBS state to the log so you can confirm it reads 0. |
| Smart App Control off | `VerifiedAndReputablePolicyState` = 0 | Section 14 already sets this in the specialize pass, so evaluation mode never starts. It's here as well for when the script is run by hand. Can't be undone, see section 14. |
| Legacy F8 boot menu | `bcdedit /set bootmenupolicy legacy` | Step 1 builds the ISO without WinRE, so this is the only way into Safe Mode when Windows won't boot. Tap F8 right after the firmware logo. Undo with `bootmenupolicy standard`. |
| svchost grouping | Sets the split threshold to the installed RAM, so services share processes the way they do on machines with under 3.5 GB RAM | About 70 svchost processes become 20 or so and roughly 100 MB of RAM comes back. No CPU gain. Not documented by Microsoft for this use. One crashing service takes its neighbours down, and Task Manager can no longer show usage per service. **CHANGE:** delete the three lines to keep services separate. Undo later by setting the value back to 3670016 and rebooting. |
| Windows search off | `DisableSearch` policy, plus the indexer service disabled | The Search process never starts, which frees about 125 MB, and typing in Start finds nothing any more. The build expects another launcher: Open-Shell as the Start menu, or Everything, or pinned apps. Needs a sign-out. **CHANGE:** delete the three lines if you want to keep Windows search. |
| StartupDelayInMSec 0 | Startup apps launch immediately after Explorer instead of after a built-in delay | Faster to a usable desktop. |
| Report | Prints SysMain state, VBS state, svchost footprint to the log | Read `C:\post-install-logs\perf.log` after install. |

Note: this script sets telemetry to 1 and the privacy script then sets it to 0. On Pro both map to "Required"; the last write wins and it does not matter.

## FirstLogon script 2: `scripts/02-privacy.ps1`

Values from the AtlasOS privacy playbook, filtered to documented policies and Settings-app toggles. No services or drivers. The one Defender setting is automatic sample submission.

| Block | Why |
|---|---|
| Diagnostic data Required, no log/dump uploads, no feedback prompts | Stops the "rate your experience" pop-ups, and limits what DiagTrack uploads if you kept that service. |
| CEIP off, Windows Error Reporting off | Crash reports stay in Event Viewer but are not uploaded. WER otherwise spawns `WerFault.exe` and phones home on every crash. |
| App compat telemetry and inventory off | The `CompatTelRunner.exe` process that scans every installed program. Famous for pegging a CPU core on idle. |
| No KMS activation ticket | Only relevant to volume licensing. Harmless on retail. |
| WDI perf-track scenario off, Device Health Attestation off, .NET CLI telemetry opt-out | Small background reporters. |
| Advertising ID off, tailored experiences off, third-party suggestions off, tips off | Ads in Settings and Start, and the tracking that feeds them. |
| App launch tracking off, instrumentation off | Windows stops recording which programs you run to build "most used". |
| Activity history off | The Timeline feature that uploaded your app history to Microsoft. |
| "Finish setting up your device" nag off, privacy questions not re-shown after feature updates | Two well-known Windows 11 interruptions. |
| Language list not sent to websites | Fingerprinting reduction. |
| Settings sync, clipboard sync, message sync, Find My Device off | Cloud features that need a Microsoft account you do not have. Each has a service that polls. |
| Cross-device features off: continue on this device, Phone-PC linking, Resume | Three policies. With all of them set, `CrossDeviceResume.exe` no longer runs. The Resume toggle in Settings alone doesn't stop it. **CHANGE:** remove the three lines if you use Phone Link or Nearby sharing. |
| Ink/typing personalization, contact harvesting, online speech off | Keystroke and handwriting samples stay local. |
| Search: no location, no dynamic content, no cloud search, no device search history | Start search does not reach the network. |
| App permission defaults: location, app diagnostics, account info, generative AI = Deny; no lock-screen camera | The Settings → Privacy toggles, set to off. |
| Windows AI: Recall off, Click To Do off, Copilot app removal policy, Notepad and Paint AI off | Recall only exists on Copilot+ hardware; these are the documented off switches so it stays off if the hardware ever changes. Copilot's removal is a real policy on Pro. |
| Office telemetry off | Harmless if Office is never installed. |
| Defender never sends file samples | The default uploads "safe" samples of unknown files to Microsoft without asking. Real-time and cloud protection stay on. Windows Security shows a yellow "Automatic sample submission is off" warning once, dismiss it. |
| Optional, commented: block Microsoft accounts entirely | Also blocks signing in to the Store and Xbox app. Off by default. |

## FirstLogon script 3: `scripts/03-interface.ps1`

Almost every value here is what the Settings app or Folder Options writes when you click the toggle, so all of it can be undone from the UI.

| Block | Why |
|---|---|
| Explorer: This PC, extensions, hidden files, compact mode, no checkboxes, no frequent/recent/cloud files in Home, full context menu even with many files selected, copy dialog with speed graph, no "look in Store" for unknown files, do not search drives for broken shortcuts, long paths, tooltips in 20 ms | Explorer stops computing "recent" and "recommended" lists, stops asking the Store what opens a file, and stops hunting drives when a shortcut target moved (the classic 30-second hang). |
| Hide Gallery and Home from the sidebar | Gallery indexes all your images to show them; Home is the recommended-files view. |
| Classic context menu | Same as section 12, as registry. On 26H2 the new menu is customisable; try that first and delete this line if it is enough. |
| Menu delay 0, Alt+Tab shows windows only (not browser tabs), Aero Shake off | Instant submenus; Alt+Tab is not flooded with Edge tabs. |
| Start: no recommendations, no account notifications, "more pins" layout, hide recently added, hide most used | An empty, static Start menu that renders instantly. |
| Task View off, End task on, no online tips in Settings | |
| Windows Spotlight off everywhere, Content Delivery Manager subscriptions off | No lock-screen ads, no "Like what you see?", no suggested content in Settings. |
| AutoPlay off, "make this PC discoverable?" pop-up off, Nearby sharing off, USB error notifications off | Four pop-ups gone. |
| Visual effects | Same set as section 15, written as the raw registry values including the `UserPreferencesMask` bit field, edited bit by bit so cursor and ClearType settings are not overwritten. Also stores wallpaper at 100 % JPEG quality instead of recompressing it. |
| Mouse acceleration off | Same as section 14. |
| Autocorrect, text prediction, spellcheck for hardware keyboards off; touch ripple off | The TabletTip service otherwise watches every keystroke. |
| No audio ducking during calls | Windows stops lowering your music when a call app opens. |
| Dynamic RGB lighting control off | Stops Windows' lighting service polling for RGB devices. |
| Blue screen: no auto-reboot, small minidump, show stop code and parameters | You can actually read the error instead of watching it reboot. |
| Verbose status on boot/shutdown screens | "Preparing..." says what it is doing. Zero cost, saves guessing. |
| Hung apps wait 2 s at shutdown instead of 5 | Faster shutdown. |
| Optional, commented: taskbar left (registry), removable drives not duplicated in sidebar, UAC without screen dimming | Off by default. The UAC one weakens UAC and is left off on purpose. |

**Restart File Explorer after scripts have run:** **ON**. **Why:** taskbar, Start and Explorer settings in the scripts take effect immediately instead of after the first reboot.

---

## Running the scripts by hand (existing install)

The scripts also work on a Windows 11 install that didn't come from this answer file. Sign in as the user you use every day (a lot of the settings are per-user), open PowerShell **as administrator**, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd "<folder with the three scripts>"
.\01-perf.ps1; .\02-privacy.ps1; .\03-interface.ps1
```

Reboot afterwards. The logs go to `C:\post-install-logs\` as usual. Keep in mind that `01-perf.ps1` turns Smart App Control off and that can't be undone.

Run by hand, you don't get what the answer file does before the first logon (app removal, Start and taskbar layout, the specialize-pass tweaks), so use the answer file when you can.

Next: back to [02-answer-file.md](02-answer-file.md#27-applocker), section 27.
