#Requires -RunAsAdministrator
# Privacy settings for Windows 11 25H2/26H2 (Pro). Companion to post-install-perf.ps1.
# Values taken from the AtlasOS playbook (rewrite branch, 2026-09), kept to documented
# policies and Settings-app toggles. Nothing here touches services, drivers or Defender.
# Run as the user you will use daily (HKCU values apply to that account). Reboot after.

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

# --- Optional - off by default -------------------------------------------

# Block Microsoft accounts entirely (local accounts only). Also blocks signing in to the
# Store/Xbox app/OneDrive, so leave it off unless you really never want an MS account.
# Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 1

# Atlas also turns off Defender's "phishing protection" (WTDS). That is a security feature
# with no performance cost; deliberately not included.

Write-Host 'Privacy settings applied. Reboot to apply everything.'
