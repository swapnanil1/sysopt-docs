# llama.cpp on an AMD GPU under CachyOS / Arch: a model in ten minutes, then the build, then the tuning

Laid out like the other guides: one file per step in [`linux/`](./linux/), scripts in [`linux/scripts/`](./linux/scripts/), and the OS-independent files in [`common/`](./common/). Written against llama.cpp `b11514`, ROCm 7.2 from Arch `extra`, CachyOS with `linux-cachyos`, Sway, October 2026.

The reference machine is the same RX 9070 16 GB (`gfx1201`), Ryzen 5 3600 and 16 GB RAM as the [Windows guide](./[01]%20Windows.md), with the [Arch guide](../[01]%20OS/[01]%20ArchAIO.md) applied. The flag measurements in the Windows guide were made on this card with the kernels the ROCm backend also uses on Linux, so they carry over; the Linux-specific numbers (absolute speed, the Vulkan backend) are expectations until the machine is booted into CachyOS and `bench.sh` is run. Each file says which is which.

The two launchers are deliberately not the same. The card-level flags carry over because the kernels are the same; the memory-dependent ones do not, because Linux leaves more of the 16 GB to the model. Step 3 says which is which and what to measure first.

What is different from Windows, in one paragraph: no SDK tarball and no compiler-driver trap, the toolchain is three pacman packages; the distribution ships a ready `llama-cpp` package with both GPU backends, so step 1 needs no build at all; memory-mapped loading is the right default; VRAM is not mirrored into host memory, so zram alone is enough and there is no pagefile effect; and there is a choice of two GPU backends (ROCm, Vulkan) on the same binary, which step 2 measures and step 3 pins in one variable.

## Folder layout

```
~/llm/
  start-llm.sh        launcher; one per model if you add more
  close-llm.sh        stops the server
  models/             the .gguf files
  logs/               server.log
  scripts/            bench.sh, build-rocm.sh, llm.service
  src/                only for a source build; binaries in src/build/bin/
```

The packaged binaries live in `/usr/bin`, the ROCm runtime in `/opt/rocm`. No environment variable is set anywhere; the build script exports `HIPCXX` and `HIP_PATH` for its own run.

## Before you start

- **CHANGE** marks the values that are yours: GPU target, model file, device, context size.
- Step 1 is enough to use a model. Steps 2 and 4 are optional; step 3 is where the speed is.
- Every step ends with a check. If yours doesn't match, stop and fix it before going on.

## Steps

| # | File | What you do | Time |
|---|---|---|---|
| 1 | [01-setup.md](./linux/01-setup.md) | Install the package, download a model, first run, launcher in place | 10 min + download |
| 2 | [02-build-rocm.md](./linux/02-build-rocm.md) | Optional: build from source for `gfx1201` with ROCm and Vulkan backends, verify, benchmark both | 1 h |
| 3 | [03-launch-and-tuning.md](./linux/03-launch-and-tuning.md) | The launcher flag by flag, Sway keybinding, optional user unit, what to re-measure and how | 20 min |
| 4 | [04-system-tuning.md](./linux/04-system-tuning.md) | What the Arch guide already did, the two GPU knobs that matter, what does nothing | reading |
| + | [common/01-reality-check.md](./common/01-reality-check.md) · [common/02-model-choice-and-speculation.md](./common/02-model-choice-and-speculation.md) | Measured speed vs hosted models; which model and which file, and the speculation trade-off | reading |

## What is in `linux/scripts/`

| File | Goes in | Used in |
|---|---|---|
| `start-llm.sh` | `~/llm` | step 1 and 3: the launcher |
| `close-llm.sh` | `~/llm` | step 3: stops the server |
| `bench.sh` | `~/llm/scripts` | steps 2 and 3: llama-bench with the server's flags, device selectable |
| `build-rocm.sh` | `~/llm/scripts` | step 2: configure and build |
| `llm.service` | `~/.config/systemd/user` | step 3: optional user unit |
