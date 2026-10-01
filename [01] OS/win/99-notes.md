# Notes

Background for the [Windows guide](../[04]%20Windows.md). Reference material, not steps.

## Where the pasted files end up

The generator doesn't link to your files, it copies their text into the XML.

| Standalone file | Copies inside `autounattend.xml` |
|---|---|
| `unattend/pe.cmd` | A chain of `RunSynchronous` commands in the `windowsPE` pass that writes `X:\pe.cmd` line by line and runs it, a readable copy in `<PEScriptCopy>`, and the generator link. |
| `scripts/01-perf.ps1`, `02-privacy.ps1`, `03-interface.ps1` | A `<File>` element each, extracted to `C:\Windows\Setup\Scripts\unattend-01.ps1` to `-03.ps1` and run at first logon, plus the generator link. |

The generator link is the long comment on line 3 of the XML. It opens the generator with the whole form filled in, pasted scripts included.

So editing a script in `scripts/` changes nothing by itself. Paste it into the generator again and download a new XML (step 6, "Changing something later").

`unattend/sync-example.ps1` does that job for the repo's example file. It writes the three `.ps1` files into `autounattend.example.xml` (the `<File>` copies and the link) and checks the result. It can only compare `pe.cmd`, because the `RunSynchronous` chain is built by the generator.

```powershell
.\sync-example.ps1          # update and verify
.\sync-example.ps1 -Check   # verify only
```

## Placeholders in the example

| Value | Placeholder | Set it in |
|---|---|---|
| User account | `User` | step 2, section 9 |
| Computer name | `MY-PC` | step 2, section 7 |
| Time zone | `UTC` | step 2, section 8 |
| Device region | United States, GeoID 244 | step 3, section 3.3 |
| Target disk size | `expected = 0` twice, which no disk matches | step 3, section 3.3 |

Left as it is, the example can't wipe a disk. The disk script stops with `No disk satisfied the given criteria` before `diskpart` runs.

## Things worth knowing

### Smart App Control

A fresh install starts SAC in evaluation mode and Windows decides later whether to enforce it. It can switch to enforcing about a week in. From then on unsigned DLLs are blocked with "Part of this app has been blocked" (seen with PostgreSQL from scoop loading `libxml2.dll`).

`HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy\VerifiedAndReputablePolicyState` is 2 in evaluation, 1 when enforcing and 0 when off. The answer file and `01-perf.ps1` both set 0. Off can't be reverted without a reinstall.

### No recovery partition

Step 1 builds without WinRE and step 3 creates no recovery partition, so Windows has no automatic repair and no built-in way into Safe Mode. `01-perf.ps1` turns the legacy F8 boot menu on for that. For anything worse, reinstall from the stick.

### Services that `01-perf.ps1` disables

Print Spooler, Server and the four Xbox services are in the disabled list even though their comments say "uncomment if". Take out the ones you need before pasting. Print to PDF needs the Spooler.

### Windows AI Fabric

`WSAIFabricSvc` hosts on-device Copilot+ models and starts on boot even on a PC without an NPU, so it is in the disabled list. The `MicrosoftWindows.Client.CoreAI` package belongs to it. That one sits in `C:\Windows\SystemApps`, is flagged non-removable and isn't a Store app, so step 1's app list can't leave it out. The guide leaves it alone.

### Windows Update error 0x8024402F

Decode the update log with `Get-WindowsUpdateLog`. If it shows `Hash check on memory file using algorithm SHA1 failed` right before the error, the scan itself worked and one of the "external cab" files came back with the wrong content. Windows fetches those over plain HTTP from `download.windowsupdate.com`.

When the expected and actual hashes keep turning up swapped between two files, the PC is being handed a valid file for the wrong request. The likely place for that is a caching proxy at the router or the ISP. A firewall isn't the cause, since the connection succeeds. Run Windows Update once over another connection (phone hotspot, VPN) to confirm.

Defender definitions stall while this lasts, because Defender asks Windows Update first. `MpCmdRun.exe -SignatureUpdate -MMPC` gets them over HTTPS instead.

## Left out

| Tweak | Why it isn't here |
|---|---|
| Ultimate Performance power plan | Balanced (or AMD Ryzen Balanced with the AMD chipset driver) already boosts fully. Ultimate Performance mostly stops cores from idling. |
| Disabling the DiagTrack service | Microsoft supports that only on fixed-function devices. The telemetry policy is the supported control and is set. |
| "Services to Manual" lists | The services on those lists are already stopped, trigger-started or disabled here. |
| svchost split threshold | Saves 100 to 300 MB of RAM and no CPU. One crashing service takes its whole group with it. It's in `01-perf.ps1` as a commented line. |
| Disabling Storage Sense, notifications or IPv6 | Each takes away something useful and gains nothing. |
| Multiplane overlay off | That's a fix for flicker on some GPUs, not a default. |
| Removing the CoreAI package | Needs an undocumented registry trick and comes back with updates. |

The guide also doesn't remove Defender, patch system files, turn off Windows Update or strip components after install. That keeps cumulative updates working (step 1, section 0).
