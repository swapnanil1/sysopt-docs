# Step 1: A model running on the GPU in ten minutes (CachyOS / Arch)

## What this step is

The shortest path from a working CachyOS desktop to a local model answering on `http://127.0.0.1:8080`. It uses the distribution's `llama-cpp` package, which ships both the Vulkan and the ROCm backend, so nothing is compiled and no ROCm SDK is installed. Step 2 is the from-source build for people who want the newest commit or a GPU-specific binary; most users never need it.

Reference machine: RX 9070 16 GB (`gfx1201`), Ryzen 5 3600, 16 GB RAM, CachyOS with the [Arch guide](../../[01]%20OS/[01]%20ArchAIO.md) applied (CachyOS repos, `linux-cachyos`, `cachyos-settings` with zram, Sway). The Arch guide's step 4 already installed `vulkan-radeon`, which is the only GPU dependency this step has.

**Not measured yet.** Unlike the Windows files, the numbers in the Linux files are expectations carried over from the Windows measurements on the same card plus community reports, until this machine is booted into CachyOS and `bench.sh` is run. Lines that need that measurement say so.

---

## 1. Folder layout

Same shape as the Windows guide, under the home directory:

```
~/llm/
  start-llm.sh        launcher; one per model if you add more
  close-llm.sh        stops the server
  models/             the .gguf files
  logs/               server.log
  scripts/            bench.sh, build-rocm.sh, llm.service
  src/                only if you build from source (step 2); the build lands in src/build/
```

No `bin/` and no `rocm/`: the package puts `llama-server` in `/usr/bin` and the ROCm runtime libraries, if the ROCm backend is used, in `/opt/rocm` via package dependencies. A source build puts its binaries in `src/build/bin/`; the launcher has one variable that selects which one runs.

```bash
mkdir -p ~/llm/{models,logs,scripts,src}
```

---

## 2. Install

```bash
sudo pacman -S --needed llama-cpp            # extra; replaces the older llama-cpp-vulkan / llama-cpp-rocm split
llama-server --version
llama-server --list-devices
```

**Check:** `--list-devices` lists the card at least once, as `Vulkan0`. If the package was built with the ROCm backend as well it also appears as `ROCm0`, and pacman will have pulled `hipblas` / `rocblas` from extra. Either is enough to continue; which one to run is decided in step 3.

If the device list is empty, Vulkan is not reachable: `vulkaninfo --summary` (package `vulkan-tools`) must show the RX 9070 under `GPU0` with the RADV driver. The Arch guide's step 4 installs exactly that; `amdvlk` must not be installed alongside it.

---

## 3. Get a model

The reference model is Qwen3.8-27B in its Swift 1.5 post-train, as the GSQ-RCO IQ3_S quant in the version that carries the model's own draft head (`-mtp` in the name, 12.1 GB). Why this model, this quant and this twin, and the alternatives for a 16 GB card, are in [common/02-model-choice-and-speculation.md](../common/02-model-choice-and-speculation.md).

The Swift repo is gated: open it in a browser once, signed in to Hugging Face, and accept the terms. Then download with a token from your account settings:

```bash
cd ~/llm/models
curl -L -O -H "Authorization: Bearer $HF_TOKEN" \
  'https://huggingface.co/ukisai/Swift-1.5-Qwen3.8-27B-GSQ-RCO-GGUF/resolve/main/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf'   # CHANGE for another model
ls -l --block-size=G
```

The plain Qwen3.8-27B twin of the same quant, for maths-heavy work, needs no token:

```bash
curl -L -O 'https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/resolve/main/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf'
```

The package's `llama-server` can also download directly with `-hf <repo>:<quant>`; it caches under `~/.cache/llama.cpp`. The explicit file in `~/llm/models` is easier to reason about and to back up.

---

## 4. First run

```bash
llama-server -m ~/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf -ngl 99 -c 16384 -fa on --port 8080
```

**Check:** the log ends with `listening on http://127.0.0.1:8080`, and in another terminal:

```bash
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say OK."}],"max_tokens":4}' | grep -o '"content":"[^"]*"'
```

`{"status":"ok"}` and a reply. The built-in web UI is at the same address in a browser.

While it runs, in a third terminal:

```bash
nvtop                                # or: watch -n1 cat /sys/class/drm/card*/device/mem_info_vram_used
```

Expect about 12 GB of VRAM used for this model at 16k context and almost nothing added to system RAM beyond the file in the page cache. There is no host-memory mirror of VRAM on Linux; the 12 GB of committed memory and the pagefile growth seen on Windows do not exist here, and zram alone is sufficient.

Ctrl+C stops it.

---

## 5. Put the launcher in place

```bash
cp scripts/start-llm.sh scripts/close-llm.sh ~/llm/ && chmod +x ~/llm/*.sh
cp scripts/bench.sh scripts/build-rocm.sh ~/llm/scripts/ && chmod +x ~/llm/scripts/*.sh
```

Edit the `MODEL=` line in `~/llm/start-llm.sh`. Step 3 explains every flag in it, the Sway keybinding, and the optional systemd user unit.

**Check:** `~/llm/start-llm.sh` in a terminal ends with `listening on`, `~/llm/close-llm.sh` in another stops it and prints `port 8080 is free`.

---

## 6. What you have now, and when to go on

A packaged build at the distribution's commit, on whichever backend the package chose, at flags that are safe but not tuned. For an afternoon of use that is enough.

Go to step 2 when one of these is true: the package is more than a few weeks behind llama.cpp master and a model you want is not supported; you want to compare the ROCm and Vulkan backends on the same commit; or you want a binary built only for `gfx1201` with the host flags for your CPU. Go to step 3 in any case before using it with a coding agent, because the flag choices there are worth 2 to 5× on prompt processing at depth and on repetitive output.
