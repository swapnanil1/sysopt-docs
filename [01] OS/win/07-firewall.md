# Step 7: Optional firewall allowlist (TinyWall)

## What this step is

Windows Firewall lets every program connect out by default. [TinyWall](https://tinywall.pados.hu) turns that around: nothing gets out unless it is on a list. The file in this step is a ready list for the Windows components only. Updates and Defender keep working, and the parts of Windows that don't need the internet stay blocked. Your own apps you add yourself, one click each.

Skip this if you don't want to approve every new program once.

## 1. Install and import

1. Install TinyWall. Tray icon > **Manage**.
2. **Maintenance** tab > **Import** > pick [firewall/tinywall-windows.tws](firewall/tinywall-windows.tws).
3. Click **Apply** in the Settings window. Nothing changes until you do.
4. Tray icon > **Change mode** > **Normal protection**.

## 2. What the file sets

Allowed:

| Rule | Why |
|---|---|
| Special exceptions: Windows Update, Windows Defender, Store update, time sync, DNS, DHCP, network discovery, ICMP | TinyWall's built-in rules. *Windows Update* allows the update service, plus outbound TCP 80 and 443 for `svchost.exe`. *Windows Defender* allows Defender's engine wherever its current version is installed. Without it, definition updates fail with `0x80072EFD` (cannot connect). |
| `MoUsoCoreWorker.exe` | Worker process of the update orchestrator. |
| `appidcertstorecheck.exe` | Scheduled task that checks the certificate store for revoked publisher certificates. |
| `TextInputHost.exe` | Touch keyboard and emoji panel. It only goes online for GIF and emoji search, so block it if you never use that. |
| `curl.exe`, `powershell.exe` | Package managers and install scripts download through these. Remove both rows if you use neither. |

Blocked (*Always block all traffic*, so Autolearn can't allow them again):

| Rule | Why |
|---|---|
| `wininit.exe`, `services.exe`, `lsass.exe` | Core system processes. `lsass` only needs the network for domain logons. |
| `rundll32.exe`, `taskhostw.exe` | Generic host processes. Malware likes them because they are signed by Microsoft. |
| `CompatTelRunner.exe` | Telemetry only. |
| `SystemSettings.exe`, `StartMenuExperienceHost.exe`, `explorer.exe` | Their only traffic is Store links, tips and web search, which step 4 already turns off. Mapped network drives still work because that traffic comes from the kernel. |
| `smartscreen.exe` | SmartScreen and Smart App Control are both off in this build. **CHANGE:** if you kept either, set this row to allow. |

Don't add `svchost.exe` as an application. The Windows Update exception already lets it connect out on ports 80 and 443. A plain `svchost.exe` row adds every other port and all inbound traffic, for every Windows service.

Don't add Defender's own files either. They live in `C:\ProgramData\Microsoft\Windows Defender\Platform\<version>\` and that path changes with every platform update. The special exception follows it.

## 3. Add your own apps

- One app: tray icon > **Whitelist by window** (Ctrl+Shift+W), then click the app's window. *By process* and *by executable* do the same from a list or a file picker.
- Many at once: **Change mode** > **Autolearn**, use the PC for a day, then go back to **Normal protection**. Autolearn allows everything it sees, so afterwards open **Manage** > **Application Exceptions** and remove what shouldn't be there.
- Block for good: double-click a row > *Always block all traffic* > OK > **Apply**. Removing a row blocks it too, but Autolearn can bring it back.
- Temporary allow: in the same dialog, *Exception lifetime* makes a rule expire at reboot or after a few hours. Handy for an installer.
- Launchers: tick *Apply same rules to child processes* on things like VS Code or Steam. The helpers they start are then covered and you don't have to chase versioned paths.

When the list is done, use **Maintenance** > **Export** and keep the file. Rows with a version number in the path stop matching after an update and have to be added again.

## 4. When something stops working

Tray icon > **Show connections**. A blocked program is marked there and right-click allows it. If it isn't in that list, the firewall isn't the cause.

| Symptom | Cause |
|---|---|
| Defender definitions fail with `0x80072EFD` | That code means "cannot connect". The *Windows Defender* special exception isn't ticked. |
| Windows Update fails with `0x8024402F` | Not the firewall. See [99-notes.md](99-notes.md). |
| An app worked yesterday and is blocked after it updated itself | Its path has a version number in it. Whitelist it again. |
| Everything is blocked | The mode is *Block all*, or you imported and never clicked **Apply**. |

## Check

1. **Manage** > **Application Exceptions**: open the `wininit.exe` row. *Always block all traffic* has to be selected.
2. Windows Security > Virus & threat protection > Protection updates > **Check for updates** works.
3. A program you haven't allowed can't reach the internet.

## Editing the file by hand

The export is plain JSON. The rules are in there twice, under `Service.Profiles[0]` and again under `Service.ActiveProfile`. Keep both the same, otherwise the import may load the copy you didn't edit. In each:

- `SpecialExceptions`: names of TinyWall's built-in rules.
- `AppExceptions[]`: one object per row. `Subject.ExecutablePath` is the program, `Policy.PolicyType` is the rule:

| `PolicyType` | Meaning |
|---|---|
| `1` | Always block all traffic |
| `2` | No restrictions |
| `3` | TCP and UDP with port lists. `"*"` in all four lists means unrestricted |
| `4` | Rule list, used by the built-in special exceptions |

`ChildProcessesInherit: true` is the *child processes* tick box. Every row needs its own `Id` (any GUID).

The live settings in `C:\ProgramData\TinyWall\config` are encrypted, so changes always go through Export and Import.
