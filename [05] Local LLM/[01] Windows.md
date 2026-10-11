# llama.cpp on an AMD GPU under Windows 11: build it yourself, run it right, know what to expect

Laid out like the other guides: one file per step in [`windows/`](./windows/), scripts in [`windows/scripts/`](./windows/scripts/), and the OS-independent files in [`common/`](./common/). The same machine under CachyOS is covered by the [Linux guide](./[02]%20Linux.md). Written against llama.cpp `b11514`, ROCm 10.1.0 (TheRock), AMD Adrenalin for ROCm 10.1, Windows 11 Pro 26H2, October 2026.

The reference machine is an RX 9070 16 GB (RDNA 4, `gfx1201`), a Ryzen 5 3600 and 16 GB of RAM, on the minimal Windows build from the [Windows guide](../[01]%20OS/[04]%20Windows.md). Every number in these files was measured on it. Other RDNA 3 or 4 cards follow the same steps with one target name changed; the memory rules are written for 16 GB and loosen with more.

What you get is a `llama-server.exe` compiled for exactly one GPU, a launch script that is tuned by measurement rather than folklore, a five-minute procedure for tuning any new model, and an honest comparison against hosted frontier models.

## Folder layout: one folder, everything inside it

AMD ships ROCm for Windows through its TheRock build system, and AMD's tooling, like llama.cpp's own Windows CI, extracts the SDK to `C:\TheRock\build`. That is a convention, not a requirement: nothing in the SDK depends on its path. This guide keeps everything under one folder instead, so that building, running and models live together and nothing reaches outside it:

```
C:\llm\
  start-llm.cmd       double-click launcher; one per model if you add more
  close-llm.cmd       stops the server
  bin\                the server and its DLLs: a copy of src\build-clang\bin
  models\             the .gguf files
  logs\               server.log, written by the server itself
  rocm\               the ROCm SDK (TheRock tarball extracted here, AMD would put it in C:\TheRock\build)
  src\                the llama.cpp source checkout; the build lands in src\build-clang\
  scripts\            configure-clang.bat, build-clang.bat, bench.ps1
```

Which path each piece reads, so nothing has to be set globally:

| Piece | Path it uses | Set by |
|---|---|---|
| Compiler and SDK | `C:\llm\rocm` (`HIP_PATH`, `CMAKE_PREFIX_PATH`) | the two build scripts, for their own window only |
| Build output | `C:\llm\src\build-clang\bin` | `configure-clang.bat` |
| Runtime DLLs | `C:\llm\bin` first (the three HIP runtime DLLs), then `C:\llm\rocm\bin` for `rocblas.dll`, `hipblas.dll` and the kernel pack | the launcher and `bench.ps1`, PATH for their own window only |
| Models and logs | `C:\llm\models`, `C:\llm\logs` | the launcher |

No user or system environment variable is needed. Any other root works; keep it short and without spaces, and change the one `ROOT` line at the top of each script.

## Before you start

- **CHANGE** marks the values that are yours: GPU target, CPU `-march`, model file, context size. The rest can stay as written.
- A build needs about 25 GB of disk and 40 minutes. A running server must be stopped before building (step 1, section 6).
- Every step ends with a check. If yours doesn't match, stop and fix it before going on.

## Steps

| # | File | What you do | Time |
|---|---|---|---|
| 1 | [01-build.md](./windows/01-build.md) | Install the driver, SDK and toolchain, build llama.cpp for one GPU, verify the GPU code is optimized, copy it into `bin\` | 1 to 2 h first time |
| 2 | [02-launch-and-tuning.md](./windows/02-launch-and-tuning.md) | The launcher and the desktop shortcut, every flag explained, what carries over between models, the five-minute tuning run, a prompt that writes the flags for you | 20 min |
| + | [common/01-reality-check.md](./common/01-reality-check.md) | Measured speed vs hosted models, where a 27B local model is and isn't enough, what would still make it faster, what to watch for | reading |
| + | [common/02-model-choice-and-speculation.md](./common/02-model-choice-and-speculation.md) | Why this model and this file, the twin that carries the speed helper, the Swift 1.5 post-train and its reasoning-effort switch, how speculative decoding trades context for speed, with the measurements | reading |

## What is in `windows/scripts/`

| File | Goes in | Used in |
|---|---|---|
| `configure-clang.bat` | `C:\llm\scripts` | step 1: CMake configure with the correct compiler driver |
| `build-clang.bat` | `C:\llm\scripts` | step 1: the build, with a job count that fits in 16 GB |
| `bench.ps1` | `C:\llm\scripts` | steps 1 and 2: llama-bench with the flags the server uses |
| `start-llm.cmd` | `C:\llm` | step 2: the double-click launcher |
| `close-llm.cmd` | `C:\llm` | step 2: stops the server however it was started |
| `start-server.ps1` | `C:\llm\scripts` | step 2: the same launch from a PowerShell window |

## The one thing to remember if you read nothing else

On Windows, compile HIP code with `clang.exe` / `clang++.exe` from the ROCm SDK, never with `clang-cl.exe`. clang-cl's `/O2` only optimizes the CPU side of the program; the GPU kernels silently come out unoptimized and run 100 times slower. Step 1, section 7 shows how to check a build in thirty seconds.
