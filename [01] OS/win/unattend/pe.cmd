@echo off

call :print "Setting keyboard layout for PE session"
wpeutil.exe SetKeyboardLayout 0409:00000409

for %%d in (C D E F G H I J K L M N O P Q T U V X Y Z) do (
    if exist %%d:\sources\install.wim set "IMAGE_FILE=%%d:\sources\install.wim"
    if exist %%d:\sources\install.esd set "IMAGE_FILE=%%d:\sources\install.esd"
    if exist %%d:\sources\install.swm set "IMAGE_FILE=%%d:\sources\install.swm" & set "SWM_PARAM=/SWMFile:%%d:\sources\install*.swm"
    if exist %%d:\autounattend.xml set "XML_FILE=%%d:\autounattend.xml"
    if exist %%d:\$WinPEDriver$ set "PEDRIVERS_FOLDER=%%d:\$WinPEDriver$"
)
for /f "tokens=3" %%t in ('reg.exe query HKLM\System\Setup /v UnattendFile 2^>nul') do ( if exist %%t set "XML_FILE=%%t" )
if not defined IMAGE_FILE call :fail "Could not locate install.wim, install.esd or install.swm."
if not defined XML_FILE call :fail "Could not locate autounattend.xml."

set "OS_VERSION=11"
for /f "tokens=3 delims=." %%v in ('ver') do (
    if %%v LSS 20000 set "OS_VERSION=10"
)

if defined PEDRIVERS_FOLDER (
    call :print "Loading drivers from $WinPEDriver$ folder"
    for /R %PEDRIVERS_FOLDER% %%f IN (*.inf) do drvload.exe "%%f"
)

>X:\target.vbs (
    echo:Function Fail(message^)
    echo:WScript.Echo message
    echo:WScript.Quit 1
    echo:End Function
    echo:On Error Resume Next
    echo:Set wmi = GetObject(^"winmgmts:\\.\root\cimv2^"^)
    echo:Set drives = wmi.InstancesOf(^"Win32_DiskDrive^"^)
    echo:If Err.Number ^<^> 0 Then
    echo:Fail ^"Could not enumerate disks: ^" ^& Err.Description
    echo:End If
    echo:Set accepted = CreateObject(^"Scripting.Dictionary^"^)
    echo:For Each drive In drives
    echo:accept = True
    echo:actual = CInt(drive.Size / 1024 / 1024 / 1024^)
    echo:expected = 0
    echo:If actual ^< expected Then
    echo:accept = False
    echo:End If
    echo:actual = CInt(drive.Size / 1024 / 1024 / 1024^)
    echo:expected = 0
    echo:If actual ^> expected Then
    echo:accept = False
    echo:End If
    echo:actual = drive.InterfaceType
    echo:If actual ^<^> ^"SCSI^" And actual ^<^> ^"IDE^" Then
    echo:accept = False
    echo:End If
    echo:actual = drive.MediaType
    echo:If actual ^<^> ^"Fixed hard disk media^" Then
    echo:accept = False
    echo:End If
    echo:If accept Then
    echo:accepted.Add drive.Index, ^"^"
    echo:End If
    echo:Next
    echo:If accepted.Count = 0 Then
    echo:Fail ^"No disk satisfied the given criteria.^"
    echo:ElseIf accepted.Count ^> 1 Then
    echo:Fail ^"Several disks (^" ^& Join(accepted.Keys, ^", ^"^) ^& ^"^) satisfied the given criteria.^"
    echo:Else
    echo:WScript.Echo Join(accepted.Keys^)
    echo:WScript.Quit 0
    echo:End If
)

call :print "Determining target disk"
(cscript.exe //E:vbscript "X:\target.vbs" //Nologo >X:\target.out) || (type X:\target.out & call :fail "Could not determine target disk. Windows Setup will halt to avoid potential data loss.")
for /f %%t in (X:\target.out) do set "TARGET_DISK=%%t"

wpeutil.exe UpdateBootInfo
for /f "tokens=3" %%t in ('reg.exe query HKLM\System\CurrentControlSet\Control /v PEFirmwareType') do (
    if %%t == 0x1 (
        set "LAYOUT=MBR"
        set "FIRMWARE=BIOS"
    ) else if %%t == 0x2 (
        set "LAYOUT=GPT"
        set "FIRMWARE=UEFI"
    ) else (
        call :fail "Unexpected PEFirmwareType value %%t."
    )
)
if not %LAYOUT% == GPT call :fail "Not booted in UEFI mode. Enable UEFI boot / disable CSM and boot the USB again."
call :print "The computer is booted in %FIRMWARE% mode, hence the target disk must be configured with the %LAYOUT% partition layout"
>X:\GPT.txt (
    echo:SELECT DISK=%TARGET_DISK%
    echo:CLEAN
    echo:CONVERT GPT
    echo:CREATE PARTITION EFI SIZE=300
    echo:FORMAT QUICK FS=FAT32 LABEL="System"
    echo:ASSIGN LETTER=S
    echo:CREATE PARTITION PRIMARY
    echo:FORMAT QUICK FS=NTFS LABEL="Windows"
    echo:ASSIGN LETTER=W
)

call :print "diskpart will now wipe, partition and format disk %TARGET_DISK%"
diskpart.exe /s X:\%LAYOUT%.txt || call :fail "diskpart.exe encountered an error."

set "IMG_PARAM=/Name:"Windows %OS_VERSION% Pro""
call :print "Applying Windows image to target disk"
dism.exe /Apply-Image /ImageFile:%IMAGE_FILE% %SWM_PARAM% %IMG_PARAM% /ApplyDir:W:\ /CheckIntegrity /Verify || call :fail "dism.exe encountered an error."

call :print "Making system partition bootable"
bcdboot.exe W:\Windows /s S: || call :fail "bcdboot.exe encountered an error."
if %LAYOUT% == GPT (
    bcdedit.exe /set {fwbootmgr} bootsequence {bootmgr} || call :fail "bcdedit.exe encountered an error."
)

call :print "Copying answer file to target disk"
mkdir W:\Windows\Panther
copy %XML_FILE% W:\Windows\Panther\unattend.xml

if defined PEDRIVERS_FOLDER (
    call :print "Adding drivers from $WinPEDriver$ folder to new installation"
    dism.exe /Add-Driver /Image:W:\ /Driver:"%PEDRIVERS_FOLDER%" /Recurse
)

call :print "Disabling 8.3 file names"
fsutil.exe 8dot3name set W: 1
fsutil.exe 8dot3name strip /s /f W:\
reg.exe LOAD HKLM\mount W:\Windows\System32\config\SYSTEM
reg.exe ADD HKLM\mount\ControlSet001\Control\FileSystem /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f
reg.exe UNLOAD HKLM\mount

call :print "Setting device setup region to United States (GeoID 244)"
reg.exe LOAD HKLM\mount W:\Windows\System32\config\SOFTWARE
reg.exe ADD "HKLM\mount\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion" /v DeviceRegion /t REG_DWORD /d 244 /f
reg.exe UNLOAD HKLM\mount

call :print "Computer will now reboot"
wpeutil.exe reboot
goto :eof

:fail
echo:
echo:Fatal error: %~1
echo:
pause
exit 1

:print
echo:
echo:*** %~1 ***
echo:
goto :eof
