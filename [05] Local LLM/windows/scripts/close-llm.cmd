@echo off
:: Stops llama-server however it was started (launcher window, hidden, or from a terminal).
:: Safe at any time: the server keeps nothing on disk, VRAM is freed the moment the process ends.
title close llama-server
tasklist /fi "imagename eq llama-server.exe" | find /i "llama-server.exe" >nul
if errorlevel 1 (
    echo llama-server is not running.
    ping -n 3 127.0.0.1 >nul
    exit /b 0
)
taskkill /im llama-server.exe >nul 2>&1
ping -n 3 127.0.0.1 >nul
tasklist /fi "imagename eq llama-server.exe" | find /i "llama-server.exe" >nul
if not errorlevel 1 taskkill /f /im llama-server.exe >nul 2>&1
echo llama-server stopped.
:: the socket can outlive the process by a few seconds; wait for it before judging the port
for /l %%i in (1,1,10) do (
    netstat -ano | findstr /r /c:":8080 .*LISTENING" >nul
    if errorlevel 1 goto portfree
    ping -n 2 127.0.0.1 >nul
)
netstat -ano | findstr /r /c:":8080 .*LISTENING" >nul
if not errorlevel 1 (
    echo Port 8080 is still held by another program:
    netstat -ano | findstr /r /c:":8080 .*LISTENING"
    echo The last number is its process id. It is not llama-server, so it was left alone.
    pause
    exit /b 1
)
:portfree
echo Port 8080 is free.
ping -n 3 127.0.0.1 >nul
