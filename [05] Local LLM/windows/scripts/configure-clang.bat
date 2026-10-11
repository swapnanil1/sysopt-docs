@echo off
setlocal
:: CMake configure for llama.cpp with the ROCm backend on Windows.
:: Uses the GNU-style clang driver (clang.exe / clang++.exe), never clang-cl. See 01-build.md section 7.1.
:: Layout: everything under ROOT (index of the guide). AMD's own tooling would put the SDK in C:\TheRock\build;
:: here it is ROOT\rocm. Nothing in the SDK depends on the path.
::
:: CHANGE: ROOT if you use another folder, GPU for your card (01-build.md 2.2), CPU for your -march value
:: (znver2/3/4/5, alderlake, or x86-64-v3 if unsure).
set "ROOT=C:\llm"
set "GPU=gfx1201"
set "CPU=znver2"

set "ROCM=%ROOT%\rocm"
set "SRC=%ROOT%\src"
set "OUT=%SRC%\build-clang"

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
set "LIB=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64;%LIB%"
set "INCLUDE=C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\ucrt;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\shared;%INCLUDE%"
set "PATH=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64;%ROCM%\bin;%ROCM%\lib\llvm\bin;%PATH%"

set "HIP_PATH=%ROCM%"
set "HIP_PLATFORM=amd"
set "HIP_DEVICE_LIB_PATH=%ROCM%\lib\llvm\amdgcn\bitcode"
set "ROCM_FWD=%ROCM:\=/%"

cmake -S "%SRC%" -B "%OUT%" -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_PREFIX_PATH=%ROCM_FWD% ^
  -DHIP_PATH=%ROCM_FWD% ^
  -DCMAKE_C_COMPILER=%ROCM_FWD%/lib/llvm/bin/clang.exe ^
  -DCMAKE_CXX_COMPILER=%ROCM_FWD%/lib/llvm/bin/clang++.exe ^
  -DCMAKE_RC_COMPILER="C:/Program Files (x86)/Windows Kits/10/bin/10.0.22621.0/x64/rc.exe" ^
  -DCMAKE_C_FLAGS="-march=%CPU%" ^
  -DCMAKE_CXX_FLAGS="-march=%CPU%" ^
  -DGGML_HIP=ON ^
  -DAMDGPU_TARGETS=%GPU% ^
  -DGGML_NATIVE=OFF ^
  -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON ^
  -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON
exit /b %ERRORLEVEL%
