#Requires -RunAsAdministrator
# Post-install performance settings for Windows 11 25H2/26H2 (Pro).
# Assumes a desktop with at least a Ryzen 5 3600 class CPU and 16 GB RAM. Fine on anything faster.
# Only documented policies, services, tasks and commands - no system file changes,
# no Defender/mitigation/driver removal. Sources: Microsoft VDI + IoT Enterprise
# service guidance, cross-checked against the AtlasOS playbook.
# Every change is reversible: delete the policy value / set the service back to its old start type.
# Smart App Control is the exception, it can't be turned back on.
# Reboot after running.

# Unattended-friendly: the window closes as soon as the script ends, so everything
# printed is also written to C:\post-install-logs\perf.log
$null = New-Item -ItemType Directory -Path "$env:SystemDrive\post-install-logs" -Force
Start-Transcript -Path "$env:SystemDrive\post-install-logs\perf.log" -Append | Out-Null
$ErrorActionPreference = 'Continue'

function Set-Policy {
    param([String]$Path, [String]$Name, $Value, [String]$Type = 'DWord')

    if(-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    # New-ItemProperty, not Set-ItemProperty: value names here can contain '*'
    $null = New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force
}

# --- Background activity -------------------------------------------------

# App Privacy > Let Windows apps run in the background = Force Deny
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2

# Widgets > Allow widgets = Disabled (no Widgets/WebView2 processes)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0

# Windows Game Recording and Broadcasting = Disabled (no background capture encoder)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0

# Delivery Optimization > Download Mode = HTTP only (no peer-to-peer upload/download work)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0

# Cloud Content > Turn off Microsoft consumer experiences (stops silent app re-installs)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1

# Search > no web results in Start search (SearchHost stops doing network + render work per keystroke)
Set-Policy 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1

# Task Scheduler > Maintenance > do not wake the PC for automatic maintenance
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Task Scheduler\Maintenance' 'WakeUp' 0

# --- Windows Update ------------------------------------------------------

# Do not include drivers with Windows Updates: stops WU replacing the GPU/chipset
# drivers you installed with an older WHQL build. Update them from the vendor yourself.
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1

# No automatic restart while someone is logged on (updates wait until you reboot)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1

# --- File Explorer -------------------------------------------------------

# Stop Explorer guessing a folder "type" (Pictures/Music/...) from its contents on every open.
# Large folders open noticeably faster, most of all on hard disks. Same value the Atlas playbook applies.
Set-Policy 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'FolderType' 'NotSpecified' 'String'

# --- Search indexing: keep it, but only for the Start menu ---------------
# Search > Default indexed paths / Default excluded paths policies.
# Start menu app search stays instant; the indexer never crawls your user folders.

$searchPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$startMenu = "file:///$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*"
$users = "file:///$env:SystemDrive\Users\*"
Set-Policy "$searchPolicy\DefaultIndexedPaths" $startMenu $startMenu 'String'
Set-Policy "$searchPolicy\DefaultExcludedPaths" $users $users 'String'

# Indexer backs off according to the active power mode
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex' 'RespectPowerModes' 1

# --- Scheduler -----------------------------------------------------------

# MMCSS: reserve 10% CPU for background work instead of the default 20%
# https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service#registry-settings
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10

# --- Services ------------------------------------------------------------
# Only services that start automatically and are marked "OK to disable" in Microsoft's
# IoT Enterprise guidance. Manual (trigger-start) services cost nothing while idle,
# so disabling them gains nothing and only breaks features.

# DiagTrack, PcaSvc, TrkWks and OneSyncSvc are deliberately NOT disabled here: the AtlasOS
# rewrite audited them and found Microsoft only supports turning those off on fixed-function
# IoT devices. The supported client controls are the two policies below.

# Application Compatibility > Turn off Program Compatibility Assistant
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisablePCA' 1

# Data Collection > diagnostic data = Required only (1 is the lowest level Pro honours)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1

$services = @(
    'MapsBroker',       # Downloaded Maps Manager
    'RetailDemo',       # Retail Demo Service
    'workfolderssvc',   # Work Folders
    'lfsvc'             # Geolocation
    'Spooler',        # Print Spooler - uncomment if you never print (also breaks Print to PDF)
    'LanmanServer',   # Server - uncomment if this PC never shares files/printers to others
    'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc',  # uncomment if no Game Pass / Xbox app
    'WSAIFabricSvc'   # Windows AI Fabric (Copilot+ model host), starts on boot even without an NPU.
                      # Not from the IoT list. WinUtil disables it too. Remove on a Copilot+ PC.
)

foreach($name in $services) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if($null -eq $svc) { continue }

    Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
    Set-Service -Name $name -StartupType Disabled
    Write-Host "Disabled $name"
}

# --- Scheduled tasks -----------------------------------------------------

$tasks = @(
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
    '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
    '\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting'
)

foreach($task in $tasks) {
    $path = Split-Path $task -Parent
    $leaf = Split-Path $task -Leaf
    $null = Disable-ScheduledTask -TaskPath "$path\" -TaskName $leaf -ErrorAction SilentlyContinue
}

# --- Disk and file system ------------------------------------------------

# No hibernation file (frees several GB) and no Fast Startup
powercfg /hibernate off

# Give back the ~7 GB Windows reserves for updates (matters on a small system drive)
DISM.exe /Online /Set-ReservedStorageState /State:Disabled

# --- Memory integrity / VBS ----------------------------------------------
# Turn off Memory Integrity and the VBS hypervisor (Microsoft's own gaming guidance).
# Biggest CPU-side gain in this file (~3-7% in CPU-bound games). Removes kernel-level
# exploit protection. Same effect as Windows Security > Core isolation > Memory integrity > Off.
# In the unattended build this is ALSO done in the specialize pass (generator option
# "VM hosts > Disable core isolation") so it is off before OOBE. It is repeated here on
# purpose so this script is complete when run by hand on any Windows 11 install.
# Re-enable: set both values to 1 (or flip the toggle in Windows Security) and reboot.
$deviceGuard = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
Set-Policy "$deviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" 'Enabled' 0
Set-Policy $deviceGuard 'EnableVirtualizationBasedSecurity' 0

# --- Smart App Control ---------------------------------------------------
# Off. A fresh install runs SAC in evaluation mode and it can switch to enforcing later.
# When it does it blocks unsigned DLLs, which hits most scoop/GitHub dev tools
# (seen with PostgreSQL's libxml2.dll about a week after install).
# Can't be undone: once off, only a reinstall brings it back.
# The answer file sets the same value in the specialize pass (generator option
# "Disable Smart App Control"). This line is for running the script by hand.
# Needs the reboot.
Set-Policy 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' 'VerifiedAndReputablePolicyState' 0

# --- Boot ----------------------------------------------------------------
# Old F8 boot menu (Safe Mode etc). The ISO has no WinRE (SkipWinRE=1 in ConvertConfig.ini),
# so this is the only way into Safe Mode when Windows won't boot.
# Tap F8 right after the firmware logo. Undo: bcdedit /set bootmenupolicy standard
bcdedit.exe /set bootmenupolicy legacy

# --- Optional, NOT officially documented - off by default ----------------

# Group services back into shared svchost.exe processes (threshold 32 GB, so it applies below that).
# Roughly 70 svchost processes become 20 and a few hundred MB of RAM come back. Trade-off: one crashing
# service takes its group down with it, and Task Manager can no longer show per-service usage.
# Set-Policy 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' 0x2000000

# Launch startup apps immediately instead of after Explorer's built-in delay
Set-Policy 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0

# --- Report only - decide these yourself ---------------------------------

Write-Host ''
Write-Host 'Memory manager state (MemoryCompression should stay on):'
Get-MMAgent

Write-Host 'Virtualization-based security state (2 = running):'
(Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus

Write-Host 'svchost footprint:'
Get-Process svchost | Measure-Object WorkingSet -Sum | ForEach-Object { '{0} processes, {1:N0} MB' -f $_.Count, ($_.Sum / 1MB) }
Write-Host 'Performance settings applied. Reboot after all scripts have run.'
Stop-Transcript | Out-Null
