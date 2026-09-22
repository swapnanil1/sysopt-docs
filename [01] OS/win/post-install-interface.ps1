#Requires -RunAsAdministrator
# Interface / quality-of-life settings for Windows 11 25H2/26H2. Companion to post-install-perf.ps1.
# Values taken from the AtlasOS playbook (rewrite branch, 2026-09). Almost all are the same
# registry values the Settings app or Folder Options write, so they can be undone from the UI.
# Run as the user you will use daily (most are HKCU). Explorer restarts at the end.

function Set-Policy {
    param([String]$Path, [String]$Name, $Value, [String]$Type = 'DWord')

    if(-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    $null = New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force
}

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$exp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'

# --- File Explorer -------------------------------------------------------

Set-Policy $adv 'LaunchTo' 1                      # open to This PC
Set-Policy $adv 'HideFileExt' 0                   # show extensions
Set-Policy $adv 'Hidden' 1                        # show hidden files
Set-Policy $adv 'UseCompactMode' 1                # tighter row spacing
Set-Policy $adv 'AutoCheckSelect' 0               # no selection check boxes
Set-Policy $exp 'ShowFrequent' 0                  # no frequent folders in Home
Set-Policy $exp 'ShowRecent' 0                    # no recent files in Home
Set-Policy $exp 'ShowCloudFilesInQuickAccess' 0   # no Office/cloud files in Home
Set-Policy $exp 'MultipleInvokePromptMinimum' 100 # full context menu even with >15 files selected
Set-Policy "$exp\OperationStatusManager" 'EnthusiastMode' 1   # copy dialog always shows speed graph
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoInternetOpenWith' 1  # no "look in Store" for unknown files
Set-Policy 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoResolveSearch' 1   # don't hunt drives for broken shortcuts
Set-Policy 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoResolveTrack' 1
Set-Policy 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1                 # paths > 260 chars
Set-Policy 'HKCU:\Control Panel\Desktop' 'MouseHoverTime' '20' 'String'                             # tooltips in 20 ms not 400

# Hide Gallery and Home from the sidebar
Set-Policy 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' 'System.IsPinnedToNameSpaceTree' 0
Set-Policy 'HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' 'System.IsPinnedToNameSpaceTree' 0

# --- Shell -------------------------------------------------------------

# Classic (Windows 10 style) right-click menu - no "Show more options" step.
# The only undocumented shell change in this file. Still works on 25H2 (checked 2026-05);
# 26H2 ships its own customisable context menu, so try that first and skip this if it's enough.
# Undo: Remove-Item 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse
Set-Policy 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(default)' '' 'String'

Set-Policy 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'   # submenus open instantly
Set-Policy $adv 'MultiTaskingAltTabFilter' 3                              # Alt+Tab: windows only, no browser tabs
Set-Policy $adv 'DisallowShaking' 1                                       # no Aero Shake
Set-Policy $adv 'Start_IrisRecommendations' 0                             # Start: no recommendations
Set-Policy $adv 'Start_AccountNotifications' 0                            # Start: no account nags
Set-Policy $adv 'Start_Layout' 1                                          # Start: more pins, less recommended
Set-Policy "$pol\Explorer" 'HideRecommendedSection' 1
Set-Policy "$pol\Explorer" 'HideRecentlyAddedApps' 1
Set-Policy "$pol\Explorer" 'ShowOrHideMostUsedApps' 2
Set-Policy $adv 'ShowTaskViewButton' 0                                    # taskbar: no Task View button
Set-Policy "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1             # taskbar: right-click > End task
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'AllowOnlineTips' 0  # no Settings tips

# Windows Spotlight / lock screen ads / "Like what you see?"
Set-Policy "$pol\CloudContent" 'DisableWindowsSpotlightFeatures' 1
Set-Policy "$pol\CloudContent" 'DisableWindowsSpotlightWindowsWelcomeExperience' 1
Set-Policy "$pol\CloudContent" 'DisableWindowsSpotlightOnActionCenter' 1
Set-Policy "$pol\CloudContent" 'DisableWindowsSpotlightOnSettings' 1
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-Policy $cdm 'RotatingLockScreenEnabled' 0
Set-Policy $cdm 'RotatingLockScreenOverlayEnabled' 0
Set-Policy $cdm 'SubscribedContent-338387Enabled' 0
Set-Policy $cdm 'SubscribedContent-353694Enabled' 0
Set-Policy $cdm 'SubscribedContent-353696Enabled' 0

# AutoPlay off, "network discoverable?" pop-up off, nearby sharing off, USB nag off
Set-Policy "$exp\AutoplayHandlers" 'DisableAutoplay' 1
$null = New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff' -Force
Set-Policy 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP' 'NearShareChannelUserAuthzPolicy' 0
Set-Policy 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP' 'CdpSessionUserAuthzPolicy' 1
Set-Policy 'HKCU:\Software\Microsoft\Shell\USB' 'NotifyOnUsbErrors' 0

# --- Visual effects (what Atlas sets: animations off, quality on) --------
# Same as Performance Options > Custom with: font smoothing, thumbnails, shadows,
# translucent selection ON; window/taskbar/menu animations and Aero Peek OFF.

Set-Policy "$exp\VisualEffects" 'VisualFXSetting' 3
# UserPreferencesMask is a bit field shared with other settings (cursor shadow, ClearType, ...).
# Change only the animation bits, the way Atlas does, instead of overwriting the whole value.
$upmPath = 'HKCU:\Control Panel\Desktop'
$upm = (Get-ItemProperty -Path $upmPath -Name UserPreferencesMask -ErrorAction SilentlyContinue).UserPreferencesMask
if($null -eq $upm -or $upm.Length -lt 8) { $upm = [byte[]](0x9E,0x1E,0x07,0x80,0x12,0x00,0x00,0x00) }
$mask = [byte[]](0x0E,0x0C,0x04,0x00,0x02,0x00,0x00,0x00)
$want = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
for($i = 0; $i -lt 8; $i++) { $upm[$i] = ($upm[$i] -band (-bnot $mask[$i])) -bor ($want[$i] -band $mask[$i]) }
Set-Policy $upmPath 'UserPreferencesMask' $upm 'Binary'
Set-Policy 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
Set-Policy 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '1' 'String'
Set-Policy 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
Set-Policy $adv 'TaskbarAnimations' 0
Set-Policy $adv 'IconsOnly' 0
Set-Policy $adv 'ListviewAlphaSelect' 1
Set-Policy $adv 'ListviewShadow' 1
Set-Policy 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
Set-Policy 'HKCU:\Software\Microsoft\Windows\DWM' 'AlwaysHibernateThumbnails' 0
Set-Policy 'HKCU:\Control Panel\Desktop' 'JPEGImportQuality' 100     # wallpaper not recompressed

# --- Input and sound -----------------------------------------------------

# Mouse acceleration ("Enhance pointer precision") off - 1:1 movement for games
Set-Policy 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
Set-Policy 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
Set-Policy 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'

# Autocorrect / text prediction / spellcheck for hardware keyboards off
$tip = 'HKCU:\Software\Microsoft\TabletTip\1.7'
foreach($n in 'EnableAutocorrection','EnableSpellchecking','EnableTextPrediction','EnablePredictionSpaceInsertion','EnableDoubleTapSpace','EnableKeyAudioFeedback') {
    Set-Policy $tip $n 0
}
Set-Policy 'HKCU:\Control Panel\Cursors' 'GestureVisualization' 0   # no touch ripple
Set-Policy 'HKCU:\Control Panel\Cursors' 'ContactVisualization' 0

# Don't lower other sounds during calls
Set-Policy 'HKCU:\Software\Microsoft\Multimedia\Audio' 'UserDuckingPreference' 3

# Dynamic (RGB) Lighting control off
Set-Policy 'HKCU:\Software\Microsoft\Lighting' 'AmbientLightingEnabled' 0

# --- Crashes, startup, shutdown -------------------------------------------

# BSoD: stay on screen (no auto reboot), keep a small minidump, log the stop code
$cc = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'
Set-Policy $cc 'AutoReboot' 0
Set-Policy $cc 'CrashDumpEnabled' 3
Set-Policy $cc 'LogEvent' 1
Set-Policy $cc 'DisplayParameters' 1

# "Preparing…" screens say what they are actually doing
Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'verbosestatus' 1

# Hung apps get 2 s instead of 5 s at shutdown
Set-Policy 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '2000' 'String'
Set-Policy 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeOut' '2000' 'String'

# --- Optional - off by default -------------------------------------------

# Taskbar icons on the left (Windows 10 style)
# Set-Policy $adv 'TaskbarAl' 0

# Removable drives only under This PC, not duplicated in the sidebar. Deletes two shell keys;
# to undo, re-create the same keys empty (they have no values).
# foreach($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}',
#               'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}') {
#     Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
# }

# UAC prompts without dimming the screen. Atlas does this; it weakens UAC (other apps can
# draw over the prompt), so deliberately left off.
# Set-Policy 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'PromptOnSecureDesktop' 0

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host 'Interface settings applied. Explorer restarted; sign out and back in for the rest.'
