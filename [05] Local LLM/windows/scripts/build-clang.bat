@echo off
setlocal
:: Build step. JOBS=4 is deliberate: the HIP compiler needs 3-5 GB per job and 16 GB of RAM
:: cannot hold six of them. Close the server window first (01-build.md section 6).
:: CHANGE: ROOT must match configure-clang.bat. JOBS: 3 on 16 GB if it still runs out of memory, 8+ on 32 GB.
set "ROOT=C:\llm"
set "JOBS=4"

set "ROCM=%ROOT%\rocm"
set "OUT=%ROOT%\src\build-clang"

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
set "LIB=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64;%LIB%"
set "INCLUDE=C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\ucrt;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\shared;%INCLUDE%"
set "PATH=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64;%ROCM%\bin;%ROCM%\lib\llvm\bin;%PATH%"

set "HIP_PATH=%ROCM%"
set "HIP_PLATFORM=amd"
set "HIP_DEVICE_LIB_PATH=%ROCM%\lib\llvm\amdgcn\bitcode"

cmake --build "%OUT%" --config Release -j %JOBS%
exit /b %ERRORLEVEL%
