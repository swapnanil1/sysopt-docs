#Requires -RunAsAdministrator
# Privacy settings for Windows 11 25H2/26H2 (Pro). Companion to 01-perf.ps1.
# Values taken from the AtlasOS playbook (rewrite branch, 2026-09), kept to documented
# policies and Settings-app toggles, with an explicit Defender-disable block
# requested for this gaming installation. Review that block before standalone use.
# Run as the user you will use daily (HKCU values apply to that account). Reboot after.

# Unattended-friendly: the window closes as soon as the script ends, so everything
# printed is also written to C:\post-install-logs\privacy.log
$null = New-Item -ItemType Directory -Path "$env:SystemDrive\post-install-logs" -Force
Start-Transcript -Path "$env:SystemDrive\post-install-logs\privacy.log" -Append | Out-Null
$ErrorActionPreference = 'Continue'

function Set-Policy {
    param([String]$Path, [String]$Name, $Value, [String]$Type = 'DWord')

    if(-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    $null = New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force
}

$pol  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$upol = 'HKCU:\Software\Policies\Microsoft\Windows'
$cu   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion'

# --- Diagnostic data and feedback ---------------------------------------

# Diagnostic data = lowest (Pro treats 0 as "Required"); no extra log/dump uploads
Set-Policy "$pol\DataCollection" 'AllowTelemetry' 0
Set-Policy "$pol\DataCollection" 'LimitDiagnosticLogCollection' 1
Set-Policy "$pol\DataCollection" 'LimitDumpCollection' 1
Set-Policy "$pol\DataCollection" 'DoNotShowFeedbackNotifications' 1
Set-Policy 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0

# Customer Experience Improvement Program
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' 0
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\AppV\CEIP' 'CEIPEnable' 0

# Windows Error Reporting (crashes still go to the Event Log, just not to Microsoft)
Set-Policy "$pol\Windows Error Reporting" 'Disabled' 1
Set-Policy "$upol\Windows Error Reporting" 'Disabled' 1

# Application compatibility telemetry / inventory
Set-Policy "$pol\AppCompat" 'AITEnable' 0
Set-Policy "$pol\AppCompat" 'DisableInventory' 1
Set-Policy "$pol\AppCompat" 'DisableUAR' 1

# Software Protection: no online KMS validation ticket (only matters for volume/KMS activation; harmless on retail)
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform' 'NoGenTicket' 1

# Responsiveness/perf-track diagnostic scenario
Set-Policy "$pol\WDI\{9c5a40da-b965-4fc3-8781-88dd50a6299d}" 'ScenarioExecutionEnabled' 0

# Device Health Attestation reporting
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\DeviceHealthAttestationService' 'EnableDeviceHealthAttestationService' 0

# .NET SDK/CLI telemetry (only matters if you install the .NET SDK)
Set-Policy 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'DOTNET_CLI_TELEMETRY_OPTOUT' '1' 'String'

# --- Advertising, tailored content, tracking ----------------------------

Set-Policy "$pol\AdvertisingInfo" 'DisabledByGroupPolicy' 1
Set-Policy "$cu\AdvertisingInfo" 'Enabled' 0
Set-Policy "$upol\CloudContent" 'DisableTailoredExperiencesWithDiagnosticData' 1
Set-Policy "$cu\Privacy" 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Policy "$pol\CloudContent" 'DisableThirdPartySuggestions' 1
Set-Policy "$pol\CloudContent" 'DisableSoftLanding' 1           # tips
Set-Policy "$pol\CloudContent" 'DisableCloudOptimizedContent' 1

# App launch tracking (Start "most used"), recent-docs tracking, user instrumentation
Set-Policy "$cu\Explorer\Advanced" 'Start_TrackProgs' 0
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoInstrumentation' 1

# Activity history / Timeline: nothing collected or uploaded
Set-Policy "$pol\System" 'EnableActivityFeed' 0
Set-Policy "$pol\System" 'PublishUserActivities' 0
Set-Policy "$pol\System" 'UploadUserActivities' 0

# "Suggest ways to finish setting up my device" nag
Set-Policy "$cu\UserProfileEngagement" 'ScoobeSystemSettingEnabled' 0

# Don't re-run the privacy questions after feature updates
Set-Policy "$pol\OOBE" 'DisablePrivacyExperience' 1

# Websites can't read your language list
Set-Policy 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1

# --- Cloud sync --------------------------------------------------------

# Settings sync, clipboard sync across devices, SMS/message sync
Set-Policy "$pol\SettingSync" 'DisableSettingSync' 2
Set-Policy "$pol\SettingSync" 'DisableSettingSyncUserOverride' 1
Set-Policy "$pol\System" 'AllowCrossDeviceClipboard' 0
Set-Policy "$pol\Messaging" 'AllowMessageSync' 0

# Cross-device: no "continue experiences on this device", no Phone-PC linking, no Resume.
# With all three set CrossDeviceResume.exe no longer runs. The Resume toggle in Settings
# alone doesn't stop it. Phone Link and Nearby sharing stop working.
Set-Policy "$pol\System" 'EnableCdp' 0
Set-Policy "$pol\System" 'EnableMmx' 0
Set-Policy 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Connectivity' 'DisableCrossDeviceResume' 1

# Find My Device location beacon
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 0

# --- Input, speech, ink --------------------------------------------------

Set-Policy 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
Set-Policy 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
Set-Policy 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0
Set-Policy 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0
Set-Policy 'HKCU:\Software\Microsoft\Input\TIPC' 'Enabled' 0
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Input\TIPC' 'Enabled' 0
Set-Policy "$pol\TabletPC" 'PreventHandwritingDataSharing' 1
Set-Policy "$pol\HandwritingErrorReports" 'PreventHandwritingErrorReports' 1
Set-Policy 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0
Set-Policy 'HKLM:\SOFTWARE\Policies\Microsoft\Speech' 'AllowSpeechModelUpdate' 0

# --- Search ------------------------------------------------------------

# ConnectedSearchUseWeb ("Don't search the web") is Enterprise/Education only - no effect on Pro.
# DisableSearchBoxSuggestions below is the Pro-supported equivalent.
Set-Policy "$pol\Windows Search" 'AllowSearchToUseLocation' 0
Set-Policy "$pol\Windows Search" 'EnableDynamicContentInWSB' 0
Set-Policy "$pol\Explorer" 'DisableSearchBoxSuggestions' 1
Set-Policy "$cu\SearchSettings" 'IsAADCloudSearchEnabled' 0
Set-Policy "$cu\SearchSettings" 'IsMSACloudSearchEnabled' 0
Set-Policy "$cu\SearchSettings" 'IsDeviceSearchHistoryEnabled' 0

# --- App permissions (Settings > Privacy & security) ---------------------

$consent = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
Set-Policy "$consent\location" 'Value' 'Deny' 'String'
Set-Policy "$consent\appDiagnostics" 'Value' 'Deny' 'String'
Set-Policy "$consent\userAccountInformation" 'Value' 'Deny' 'String'
Set-Policy "$consent\generativeAI" 'Value' 'Deny' 'String'
Set-Policy "$pol\Personalization" 'NoLockScreenCamera' 1

# --- AI features ---------------------------------------------------------
# Recall and Click To Do only exist on Copilot+ (NPU) hardware; on this PC these policies are
# documented, Pro-supported no-ops that keep them off if the hardware ever changes.

Set-Policy "$pol\WindowsAI" 'DisableAIDataAnalysis' 1          # Recall snapshots
Set-Policy "$pol\WindowsAI" 'AllowRecallEnablement' 0
Set-Policy "$pol\WindowsAI" 'DisableClickToDo' 1
# DisableSettingsAgent is Enterprise/Education + Insider only per the WindowsAI CSP - omitted.
Set-Policy "$pol\WindowsAI" 'RemoveMicrosoftCopilotApp' 1   # CSP text: Enterprise, Professional and Education
Set-Policy 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableCocreator' 1
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableImageCreator' 1
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableGenerativeFill' 1

# --- Office (harmless if Office is never installed) ---------------------

Set-Policy 'HKCU:\Software\Policies\Microsoft\office\16.0\common' 'sendcustomerdata' 0
Set-Policy 'HKCU:\Software\Policies\Microsoft\office\16.0\common' 'qmenable' 0
Set-Policy 'HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry' 'sendtelemetry' 3

# --- Defender: first-logon follow-up to the offline PE settings -----------
# These are requests, not a tamper-protection bypass. Registry readback does
# not prove the running engine honored a policy. Updates can restore settings.
# Deprecated DisableAntiSpyware/DisableAntivirus and TamperProtection hacks
# are deliberately omitted. Scope is Defender plus its tray startup entry.
$script:defenderFailures = 0
function Invoke-DefenderChange {
    param([string]$Label, [scriptblock]$Action)
    try {
        & $Action
        Write-Host "Defender configuration: $Label"
    } catch {
        $script:defenderFailures++
        Write-Warning "Defender configuration blocked/failed ($Label): $($_.Exception.Message)"
    }
}

$defenderRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$defenderPolicies = [ordered]@{
    'Real-Time Protection' = [ordered]@{
        DisableRealtimeMonitoring = 1
        DisableBehaviorMonitoring = 1
        DisableOnAccessProtection = 1
        DisableIOAVProtection = 1
        DisableScanOnRealtimeEnable = 1
    }
    'Spynet' = [ordered]@{
        SpynetReporting = 0
        SubmitSamplesConsent = 2
        DisableBlockAtFirstSeen = 1
    }
}
foreach ($group in $defenderPolicies.Keys) {
    foreach ($name in $defenderPolicies[$group].Keys) {
        $path = "$defenderRoot\$group"
        $value = $defenderPolicies[$group][$name]
        Invoke-DefenderChange "policy $group/$name requested as $value" {
            if (-not (Test-Path $path)) {
                $null = New-Item -Path $path -Force -ErrorAction Stop
            }
            $null = New-ItemProperty -Path $path -Name $name -Value $value -PropertyType DWord -Force -ErrorAction Stop
            if ((Get-ItemPropertyValue -Path $path -Name $name -ErrorAction Stop) -ne $value) {
                throw 'Registry value did not retain the requested value.'
            }
        }
    }
}

# If an existing/running engine is present, ask it to change settings too.
# Fresh installs normally skip this because pe.cmd already disabled its service.
if ((Get-Service -Name WinDefend -ErrorAction SilentlyContinue).Status -eq 'Running') {
    $preferences = [ordered]@{
        DisableRealtimeMonitoring = $true
        DisableBehaviorMonitoring = $true
        DisableIOAVProtection = $true
        DisableScriptScanning = $true
        DisableBlockAtFirstSeen = $true
        MAPSReporting = 0
        SubmitSamplesConsent = 2
    }
    foreach ($name in $preferences.Keys) {
        Invoke-DefenderChange "engine preference $name" {
            $arguments = @{ ErrorAction = 'Stop' }
            $arguments[$name] = $preferences[$name]
            Set-MpPreference @arguments
            $actual = (Get-MpPreference -ErrorAction Stop).$name
            if ($null -eq $actual -or [int]$actual -ne [int]$preferences[$name]) {
                throw 'Engine preference was not applied; check tamper protection or managed policy.'
            }
        }
    }
    Invoke-DefenderChange 'report effective engine state' {
        $status = Get-MpComputerStatus -ErrorAction Stop
        $status | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, BehaviorMonitorEnabled, IoavProtectionEnabled, IsTamperProtected | Format-List
        if ($status.RealTimeProtectionEnabled) {
            throw 'Real-time protection is still enabled.'
        }
    }
} else {
    Write-Host 'Defender engine is not running; engine preference calls skipped.'
}

# Reassert only the six services/drivers handled in pe.cmd, if installed.
# Loaded kernel drivers are not forcibly unloaded; startup changes need a reboot.
foreach ($name in 'Sense', 'WdBoot', 'WdFilter', 'WdNisDrv', 'WdNisSvc', 'WinDefend') {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
    if (Test-Path $path) {
        Invoke-DefenderChange "$name startup disabled" {
            $null = New-ItemProperty -Path $path -Name Start -Value 4 -PropertyType DWord -Force -ErrorAction Stop
            if ((Get-ItemPropertyValue -Path $path -Name Start -ErrorAction Stop) -ne 4) {
                throw 'Service startup setting did not remain disabled.'
            }
        }
    }
}
foreach ($name in 'Sense', 'WdNisSvc', 'WinDefend') {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Stopped') {
        Invoke-DefenderChange "stop $name" {
            Stop-Service -Name $name -ErrorAction Stop
        }
    }
}

Invoke-DefenderChange 'disable Defender scheduled tasks' {
    # Enumerate first: no Defender task folder is a valid state on a stripped image.
    $tasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -eq '\Microsoft\Windows\Windows Defender\' })
    foreach ($task in $tasks) {
        Invoke-DefenderChange "task $($task.TaskName)" {
            $null = Disable-ScheduledTask -InputObject $task -ErrorAction Stop
            Stop-ScheduledTask -InputObject $task -ErrorAction Stop
            if ((Get-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop).State -ne 'Disabled') {
                throw 'Scheduled task did not remain disabled.'
            }
        }
    }
}

# Hide the logon tray process without disabling Security Center, firewall,
# UAC, Windows Update, or services used to report other security features.
foreach ($path in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') {
    Invoke-DefenderChange 'remove SecurityHealth tray autorun if present' {
        if (Test-Path $path) {
            $entry = Get-ItemProperty -Path $path -ErrorAction Stop
            if ($entry.PSObject.Properties['SecurityHealth']) {
                Remove-ItemProperty -Path $path -Name SecurityHealth -ErrorAction Stop
            }
        }
    }
}
Get-Process -Name SecurityHealthSystray -ErrorAction SilentlyContinue | ForEach-Object {
    $trayProcess = $_
    Invoke-DefenderChange 'stop Windows Security tray process' {
        Stop-Process -Id $trayProcess.Id -ErrorAction Stop
    }
}
Invoke-DefenderChange 'report service state' {
    Get-CimInstance Win32_Service -Filter "Name='WinDefend' OR Name='WdNisSvc' OR Name='Sense'" -ErrorAction Stop |
        Select-Object Name, State, StartMode | Format-Table -AutoSize
    Get-CimInstance Win32_SystemDriver -Filter "Name='WdBoot' OR Name='WdFilter' OR Name='WdNisDrv'" -ErrorAction Stop |
        Select-Object Name, State, StartMode | Format-Table -AutoSize
}
Write-Host "Defender configuration finished with $script:defenderFailures blocked/failed operations. Reboot and verify; future updates can restore settings."

# --- Optional - off by default -------------------------------------------

# Block Microsoft accounts entirely (local accounts only). Also blocks signing in to the
# Store/Xbox app/OneDrive, so leave it off unless you really never want an MS account.
# Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 1

# Atlas also turns off Defender's "phishing protection" (WTDS). That is a security feature
# with no performance cost; deliberately not included.

Write-Host 'Privacy settings applied. Reboot after all scripts have run.'
Stop-Transcript | Out-Null
