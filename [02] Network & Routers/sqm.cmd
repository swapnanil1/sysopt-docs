@echo off
:: Menu for the shaper (SQM, cake) on the OpenWrt bridge. Double-click for the menu, or give the
:: action on the command line for a shortcut:  sqm.cmd on | off | toggle | status | key
::
:: One SSH session per action. The box prints the state it is in, then switches in the background,
:: because stopping or starting the shaper on eth1 drops the session that carried the command.
:: Without a key each action asks for the root password once; "key" installs one and ends that.
:: Key: SQM_KEY=<file> picks a private key; otherwise .ssh\id_wr845n if it exists; otherwise ssh's
:: own rules (a Host block in .ssh\config, the agent). SQM_BOX overrides the address.
setlocal
if not defined SQM_BOX set "SQM_BOX=192.168.1.245"
set "DEV=eth1"
set "SSH=%SystemRoot%\System32\OpenSSH\ssh.exe -o HostKeyAlgorithms=+ssh-rsa -o ConnectTimeout=5"
if not defined SQM_KEY if exist "%USERPROFILE%\.ssh\id_wr845n" set "SQM_KEY=%USERPROFILE%\.ssh\id_wr845n"
if defined SQM_KEY if exist "%SQM_KEY%" set "SSH=%SSH% -i "%SQM_KEY%" -o IdentitiesOnly=yes"

if not "%~1"=="" (
    for %%a in (on off toggle status key) do if /i "%~1"=="%%a" ( call :%%a & exit /b )
    echo unknown action "%~1": on, off, toggle, status, key
    exit /b 1
)

:menu
echo.
echo   SQM on %SQM_BOX%
echo.
echo   1  status
echo   2  on
echo   3  off
echo   4  toggle
echo   5  key      install an SSH key, no more passwords
echo   q  quit
echo.
set "c="
set /p "c=> "
if "%c%"=="1" call :status
if "%c%"=="2" call :on
if "%c%"=="3" call :off
if "%c%"=="4" call :toggle
if "%c%"=="5" call :key
if "%c%"=="q" exit /b
if "%c%"=="" exit /b
goto menu

:status
%SSH% root@%SQM_BOX% "if tc qdisc show dev %DEV% | grep -q cake; then echo 'SQM on: cake on %DEV%'; else echo 'SQM off: no shaper on %DEV%'; fi"
exit /b

:on
%SSH% root@%SQM_BOX% "if tc qdisc show dev %DEV% | grep -q cake; then echo 'already on'; else echo 'was off, switching on (about 5 s)'; ( sleep 1; /etc/init.d/sqm start ) >/dev/null 2>&1 & fi"
exit /b

:off
%SSH% root@%SQM_BOX% "if tc qdisc show dev %DEV% | grep -q cake; then echo 'was on, switching off (about 5 s)'; ( sleep 1; /etc/init.d/sqm stop ) >/dev/null 2>&1 & else echo 'already off'; fi"
exit /b

:toggle
%SSH% root@%SQM_BOX% "if tc qdisc show dev %DEV% | grep -q cake; then echo 'was on, switching off (about 5 s)'; ( sleep 1; /etc/init.d/sqm stop ) >/dev/null 2>&1 & else echo 'was off, switching on (about 5 s)'; ( sleep 1; /etc/init.d/sqm start ) >/dev/null 2>&1 & fi"
exit /b

:key
if not defined SQM_KEY set "SQM_KEY=%USERPROFILE%\.ssh\id_wr845n"
if not exist "%SQM_KEY%" ssh-keygen -t ed25519 -N "" -f "%SQM_KEY%" -C wr845n >nul
if not exist "%SQM_KEY%.pub" ( echo no public key next to "%SQM_KEY%" & exit /b 1 )
echo installing "%SQM_KEY%.pub", last password prompt:
type "%SQM_KEY%.pub" | %SystemRoot%\System32\OpenSSH\ssh.exe -o HostKeyAlgorithms=+ssh-rsa root@%SQM_BOX% "mkdir -p /etc/dropbear; cat >> /etc/dropbear/authorized_keys; chmod 600 /etc/dropbear/authorized_keys; echo key installed"
%SystemRoot%\System32\OpenSSH\ssh.exe -o HostKeyAlgorithms=+ssh-rsa -i "%SQM_KEY%" -o IdentitiesOnly=yes -o BatchMode=yes root@%SQM_BOX% "echo login without a password works"
exit /b
