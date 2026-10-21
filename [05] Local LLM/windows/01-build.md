# Step 1: Build llama.cpp for one AMD GPU on Windows 11

## What this step is

Everything from a bare Windows install to a verified, optimized `llama-server.exe` for a single GPU target, copied into `C:\llm\bin`. Sections 1 and 2 are the install order. Section 4 is the build. Sections 5 to 7 are the checks and the traps; do not skip them.

Recommended baseline and example build target (adapt to your hardware):

| Part | Value |
|---|---|
| GPU | RX 9070-class AMD graphics or better with at least 16 GB VRAM; `gfx1201` is the RX 9070 example target |
| CPU | Ryzen 5 3600-class or better; select compiler features for your CPU |
| RAM | At least 16 GB |
| OS | Windows 11 Pro, minimal build, Scoop for packages (winget works the same) |
| Driver | AMD Software: Adrenalin Edition for ROCm 10.1 (26.10.41.05) |
| ROCm | TheRock 10.1.0 tarball, extracted to `C:\llm\rocm` |

---

## 1. Why build it at all

The official release zip (`llama-bNNNNN-bin-win-rocm-10.x-x64.zip`) works and is fast. A self-built binary gives three things, and only these:

1. **A smaller GPU backend.** The official `ggml-hip.dll` carries kernels for nine GPU families and is about 1 GB. One built for a single target is about 290 MB.
2. **The newest commit.** New model architectures and speed work land in llama.cpp weekly. The release zip lags by hours to days; a local build can track master.
3. **Control over compile-time options.** Things like `GGML_CUDA_FA_ALL_QUANTS` or `GGML_HIP_GRAPHS` can be flipped and tested. None of them changed anything on the reference GPU, but that is only known because it was tried.

It does **not** give raw speed over the official build. The official build is compiled correctly. Measured on the benchmark configuration, same 27B model, same flags:

| Build | Prompt processing (pp512) | Decode (tg) |
|---|---|---|
| Official zip, b11503 | ~700–800 tok/s | ~28–31 tok/s |
| Self-built, correct (this step) | 1034 tok/s | 32.4 tok/s |
| Self-built, with the clang-cl mistake (section 7.1) | 4.7 tok/s | 0.6 tok/s |

The small gain in the second row comes from a newer commit, not from the custom compile.

---

## 2. Dependencies, in install order

### 2.1 GPU driver: Adrenalin for ROCm

Download **AMD Software: Adrenalin Edition for ROCm 10.1** from AMD. It is a separate download from the gaming Adrenalin. It installs HIP runtime pieces into `C:\Windows\System32` (`amdhip64_7.dll`, `amd_comgr_3.dll`); section 5.2 explains why that matters.

**Check:** Device Manager → Display adapters → your GPU → Driver version `26.10.41.05` or newer, with "for ROCm" in the package name.

### 2.2 ROCm SDK: the TheRock tarball

ROCm for Windows ships from AMD's TheRock project as one tarball per GPU family. AMD's tooling and llama.cpp's CI extract it to `C:\TheRock\build`; this guide extracts it to `C:\llm\rocm`, which works identically because nothing in the SDK depends on its location. Pick the family that contains your target:

| Card | Target (CHANGE) | Tarball family |
|---|---|---|
| RX 9070 / 9070 XT | gfx1201 | gfx120X |
| RX 9060 XT | gfx1200 | gfx120X |
| RX 7900 XTX / XT / GRE | gfx1100 | gfx110X |
| RX 7800 XT / 7700 XT | gfx1101 | gfx110X |
| RX 7600 | gfx1102 | gfx110X |
| Ryzen AI Max (Strix Halo) | gfx1151 | gfx1151 |
| RX 6800 / 6900 | gfx1030 | gfx103X |

For the benchmark configuration: `therock-dist-windows-gfx120X-all-10.1.0.tar.gz` (about 2.2 GB) from the TheRock GitHub releases. Extract it; Windows has `tar` built in:

```powershell
New-Item -ItemType Directory -Force C:\llm\rocm, C:\llm\models, C:\llm\logs, C:\llm\bin, C:\llm\scripts | Out-Null
tar -xzf .\therock-dist-windows-gfx120X-all-10.1.0.tar.gz -C C:\llm\rocm
```

Keep the tarball on a spare drive; it is the only way to restore `rocm\` without a new download.

**Check:** these must exist afterwards.

```
C:\llm\rocm\bin\amdhip64_7.dll          HIP runtime
C:\llm\rocm\bin\rocm_kpack.dll          kernel-pack loader (amdhip64 depends on it)
C:\llm\rocm\bin\amd_comgr.dll           code object manager
C:\llm\rocm\bin\rocblas.dll             BLAS (linked, rarely used on RDNA 4)
C:\llm\rocm\bin\hipblas.dll
C:\llm\rocm\lib\llvm\bin\clang.exe      the compilers
C:\llm\rocm\lib\llvm\bin\clang++.exe
C:\llm\rocm\lib\llvm\bin\lld-link.exe
C:\llm\rocm\lib\cmake\hip\              CMake config files
C:\llm\rocm\.kpack\blas_lib_gfx1201.kpack   kernels for your target (name varies)
```

And `C:\llm\rocm\lib\llvm\bin\clang++.exe --version` prints an AMD/ROCm clang.

### 2.3 No environment variables

Nothing in this guide sets a user or system variable. The build scripts set `HIP_PATH` and PATH for their own window, the launcher sets PATH for its own window. If an earlier setup left `HIP_PATH` or a ROCm folder in the user PATH, remove them; a stale one pointing at a deleted folder is a confusing failure later.

### 2.4 Visual Studio 2022 Build Tools

The ROCm clang targets the MSVC ABI, so it needs Microsoft's C runtime headers, import libraries and `link.exe`. The IDE is not needed. Download `vs_BuildTools.exe` from the Visual Studio downloads page (under "Tools for Visual Studio") and install exactly these two components:

```
Microsoft.VisualStudio.Component.VC.Tools.x86.x64      MSVC v143 x64/x86 build tools
Microsoft.VisualStudio.Component.Windows11SDK.22621     Windows 11 SDK 10.0.22621
```

Unattended:

```
vs_BuildTools.exe --passive --wait --norestart ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621
```

**Check:** `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat` exists.

### 2.5 CMake, Ninja, Git

```powershell
scoop install cmake ninja git
# or
winget install Kitware.CMake Ninja-build.Ninja Git.Git
```

**Check:** `cmake --version` is 3.21 or newer (4.x is fine), `ninja --version` and `git --version` run.

### 2.6 Nothing else

No Python, no CUDA, no HIP SDK installer, no rocWMMA. Guides that ask for those are describing an older llama.cpp.

---

## 3. Get the source

```powershell
cd C:\llm
git clone https://github.com/ggml-org/llama.cpp src
cd src
git fetch --tags
git checkout b11514        # CHANGE: any tag; `git tag --sort=-v:refname | Select-Object -First 5` lists the newest
```

Tags are `bNNNNN` and match the release zip names, so a build can always be compared against the official binary of the same commit.

Copy [`scripts/configure-clang.bat`](./scripts/configure-clang.bat), [`scripts/build-clang.bat`](./scripts/build-clang.bat) and [`scripts/bench.ps1`](./scripts/bench.ps1) into `C:\llm\scripts`, and edit the **CHANGE** lines at the top of the two batch files.

---

## 4. Configure and build

```powershell
C:\llm\scripts\configure-clang.bat
C:\llm\scripts\build-clang.bat
```

Configure takes about ten seconds. The build takes 25 to 40 minutes on a six-core CPU.

What the configure script does, so it can be adapted:

```bat
set "ROOT=C:\llm"                                           :: the only path to change if you use another root
set "ROCM=%ROOT%\rocm"   set "SRC=%ROOT%\src"   set "OUT=%SRC%\build-clang"
set "GPU=gfx1201"        set "CPU=znver2"                   :: CHANGE

call "...\BuildTools\VC\Auxiliary\Build\vcvars64.bat"      :: MSVC headers, libs and link.exe into the environment
set LIB=...\10.0.22621.0\um\x64;...\ucrt\x64;%LIB%          :: SDK libs, in case vcvars did not add them
set INCLUDE=...\10.0.22621.0\um;...\ucrt;...\shared;%INCLUDE%
set HIP_PATH=%ROCM%                                         :: read by the HIP CMake config
set HIP_PLATFORM=amd
set HIP_DEVICE_LIB_PATH=%ROCM%\lib\llvm\amdgcn\bitcode

cmake -S %SRC% -B %OUT% -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_PREFIX_PATH=<rocm>                                :: where find_package(hip, rocblas, hipblas) looks
  -DHIP_PATH=<rocm>
  -DCMAKE_C_COMPILER=<rocm>/lib/llvm/bin/clang.exe          :: GNU-style driver. Not clang-cl. See 7.1
  -DCMAKE_CXX_COMPILER=<rocm>/lib/llvm/bin/clang++.exe      :: same
  -DCMAKE_RC_COMPILER="C:/Program Files (x86)/Windows Kits/10/bin/10.0.22621.0/x64/rc.exe"
  -DCMAKE_C_FLAGS="-march=%CPU%"                            :: host CPU only; does not touch GPU code
  -DCMAKE_CXX_FLAGS="-march=%CPU%"
  -DGGML_HIP=ON
  -DAMDGPU_TARGETS=%GPU%                                    :: your target only. Several: "gfx1201;gfx1100"
  -DGGML_NATIVE=OFF
  -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON                :: CPU backend ISA, matches Zen 2
  -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON
```

`-march` values: Zen 2 `znver2`, Zen 3 `znver3`, Zen 4 `znver4`, Zen 5 `znver5`, Intel 12th to 14th gen `alderlake`, unsure `x86-64-v3`. It only tunes the small CPU-side code paths.

The build script is one line, `cmake --build C:\llm\src\build-clang --config Release -j 4`. `-j 4` is deliberate; section 6 says why.

**Check:** `C:\llm\src\build-clang\bin\` contains `llama-server.exe`, `llama-bench.exe` and a `ggml-hip.dll` of roughly 290 MB for one target.

---

## 5. After the build

### 5.1 Verify the GPU code is optimized (thirty seconds)

```powershell
Select-String -Path C:\llm\src\build-clang\build.ninja -Pattern 'FLAGS = .*-x hip' | Select-Object -First 1
```

**Check:** the line contains `-O3` and `--offload-arch=gfx1201`. If it contains `/O2` instead, the configure used clang-cl. Delete `build-clang` and return to section 4.

### 5.2 Copy into `bin\`, with the three HIP runtime DLLs

```powershell
Copy-Item C:\llm\src\build-clang\bin\* -Destination C:\llm\bin -Force
Copy-Item C:\llm\rocm\bin\amdhip64_7.dll, C:\llm\rocm\bin\rocm_kpack.dll, C:\llm\rocm\bin\amd_comgr.dll -Destination C:\llm\bin -Force
```

The driver installs its own `amdhip64_7.dll` into `System32`, and Windows searches `System32` before PATH. A copy in the executable's own directory is searched first and wins. The official release zip bundles the same three files for the same reason. `rocblas.dll` and `hipblas.dll` stay in `rocm\bin` with their kernel pack; the launcher puts that folder on PATH.

**Check:** `C:\llm\bin\llama-server.exe` and `C:\llm\bin\amdhip64_7.dll` exist.

### 5.3 Benchmark

```powershell
C:\llm\scripts\bench.ps1 -Model C:\llm\models\your-model.gguf
```

**Check:** for a 27B model at IQ3_S (11 GB) on the reference GPU, `pp512` is about 1000 and `tg` about 32. For other models, `pp512` in the hundreds or above is healthy. Below 100 means unoptimized GPU code (7.1). A missing-DLL error at startup means 5.2 was skipped.

### 5.4 Put the launcher in place

Copy [`scripts/start-llm.cmd`](./scripts/start-llm.cmd) to `C:\llm\start-llm.cmd` and change its `-m` line to the model's file name. Step 2 covers the shortcut and the flags.

**Check:** double-clicking `C:\llm\start-llm.cmd` opens a window that ends with `listening on http://127.0.0.1:8080`.

---

## 6. Memory on a 16 GB machine

Two rules that are not obvious:

1. **The HIP compiler needs 3 to 5 GB of RAM per job** on the flash-attention and matrix-multiply template files. `-j 6` on 16 GB fails with `LLVM ERROR: out of memory` or `The paging file is too small`. Use `-j 3` or `-j 4`. Ninja resumes where it stopped, so a failed build just needs re-running with a lower count.
2. **A running llama-server commits about 14 GB of host memory** even with every layer on the GPU and memory-mapping disabled. Under WDDM the HIP runtime commits host backing for every VRAM allocation. It is not resident RAM, but it counts against the commit limit (RAM plus pagefile). Stop the server before building.
3. **Set the pagefile to a fixed 32 GB** (initial = maximum = 32768 MB: System → Advanced system settings → Performance → Settings → Advanced → Virtual memory; reboot). With 16 GB of RAM the commit limit is RAM plus pagefile, and a 16 GB maximum is not enough: the server's 14 GB plus a browser and an editor reached 30 of 30 GB during prompt processing of a 10k-token prompt, and the server died with `got exception: bad allocation` followed by a `GGML_ASSERT` crash. Almost nothing is written to the pagefile (usage stayed near 1 GB); it only has to exist so the commit can be guaranteed. A fixed size also stops Windows growing and shrinking the file on every start.

---

## 7. Traps

### 7.1 clang-cl compiles the GPU kernels at -O0

`clang-cl.exe` accepts `/O2`, but the driver only translates it for the host (x86) compile. The HIP device compile receives no optimization flag and defaults to -O0. Every GPU kernel then spills registers to scratch memory. Symptoms: prompt processing in the single digits of tokens per second, decode below 1 tok/s, Task Manager showing near-zero GPU use (the GPU is stalled on scratch traffic) and one busy CPU thread (the HIP runtime spin-waiting on the GPU). It looks exactly like a silent fallback to the CPU backend, and it is not one.

To see it for any compiler setup:

```powershell
clang-cl -### /O2 -x hip --offload-arch=gfx1201 -c foo.hip 2>&1 | Select-String amdgcn
clang++  -### -O3 -x hip --offload-arch=gfx1201 -c foo.hip 2>&1 | Select-String amdgcn
```

The first prints a device job with no `-O`. The second prints `-O3`. On a small test kernel the difference was 1468 instructions with 71 scratch spills versus about 200 instructions with none.

Rule: use `clang.exe` / `clang++.exe` for HIP, as llama.cpp's own CI does. If clang-cl is unavoidable, add `/clang:-O3` to `CMAKE_CXX_FLAGS`; it reaches the device job.

### 7.2 Keep the official zip and your build apart

If you also download a release zip, extract it to its own folder and never copy a build over it. Without a pristine reference binary, every "official versus custom" comparison compares a file to itself. Which build is serving is visible at `http://127.0.0.1:8080/props` under `build_info`: a release zip reports its tag, a local build reports its checkout commit.

### 7.3 Dead knobs

`GGML_HIP_ROCWMMA_FATTN` no longer exists (flash attention on RDNA uses WMMA intrinsics directly). `HSA_OVERRIDE_GFX_VERSION` is a Linux variable with no effect on Windows. `ROCBLAS_USE_HIPBLASLT` does nothing for quantized models on RDNA 4 because llama.cpp routes every quantized matrix multiply through its own MMQ kernels and never calls rocBLAS. Setting them is harmless; expecting anything from them is not.

### 7.4 `-lm none` replaced `--no-mmap`

Recent versions removed `--no-mmap` in favour of `--load-mode none` (`-lm none`). The server rejects the old flag and names the new one.

---

## 8. Updating later

```powershell
# close the server window first
cd C:\llm\src
git fetch --tags
git checkout b12000                 # CHANGE: newest tag
C:\llm\scripts\build-clang.bat      # configure is cached; rerun configure-clang.bat only if CMake files changed
```

Then repeat 5.1, 5.2 and 5.3. The launcher does not change. Five minutes of checking keeps a broken build out of the editors.

---

## 9. Migrating from the stock `C:\TheRock` layout

If the SDK and source already live where AMD's tooling puts them, they can be moved into `C:\llm` rather than re-extracted and re-cloned: `C:\TheRock\build` becomes `C:\llm\rocm`, the checkout becomes `C:\llm\src`. Nothing in the SDK or the source cares about its path. Two things do:

1. **The CMake cache.** `build-clang\CMakeCache.txt` records the directory it was created in, and CMake refuses to configure a moved build directory. Delete `build-clang\CMakeCache.txt` and `build-clang\CMakeFiles\`, rerun `configure-clang.bat`, and expect the next `build-clang.bat` to be a full rebuild because every compile command now has a new source path. The already-built binaries in `build-clang\bin` are still valid and can be copied to `bin\` as in 5.2 while that rebuild is pending.
2. **Open handles.** Close any editor or terminal that has the old folder open before moving it. With a handle held inside `.git`, the move degrades from an instant rename into a copy that can stop halfway. If that happens, `robocopy <old> <new> /E /MOVE` finishes the job and retries locked files.

Any `HIP_PATH` or PATH entries pointing at the old folder should be removed afterwards (2.3); the scripts set what they need themselves.
