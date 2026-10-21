# Step 1: A model running on the GPU in ten minutes (CachyOS / Arch)

## What this step is

The shortest path from a working CachyOS desktop to a local model answering on `http://127.0.0.1:8080`. It uses the distribution's `llama-cpp` package plus the GPU backend packages that go with it (`ggml-vulkan`, and optionally `ggml-hip` for ROCm), so nothing is compiled and no ROCm SDK is installed. Step 2 is the from-source build for people who want the newest commit or a GPU-specific binary; most users never need it.

Recommended baseline for the supplied 27B examples: an RX 9070-class AMD GPU with at least 16 GB VRAM, a Ryzen 5 3600-class CPU or better, and at least 16 GB system RAM. These are guide assumptions, not hard minimums for llama.cpp; smaller models can run on less hardware. Check backend support and adjust the GPU target, context, and thread count for your system. This step assumes CachyOS / Arch with the [Arch guide](../../[01]%20OS/[01]%20ArchAIO.md) applied as needed; Sway is optional. The Arch guide's step 4 already installed `vulkan-radeon`, which is the only GPU dependency this step has.

**Performance figures.** Step 3 labels recorded Linux Vulkan results separately from unmeasured ROCm settings. Run `bench.sh` on your hardware before relying on a context size or throughput figure.

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

**Home on a hard disk?** Put the folder on the SSD and leave a symlink at `~/llm`, so every path in this guide and in the scripts still works. The model file is memory-mapped: the first load reads all 12 GB, and so does every reload after the page cache has dropped it, which on a hard disk is a minute and a half each time against a few seconds on NVMe. The games subvolume from the Arch guide's fstab step is the natural place, since it is already excluded from Timeshift snapshots and owned by your user:

```bash
mkdir -p /mnt/games/llm/{models,logs,scripts,src}
ln -s /mnt/games/llm ~/llm
```

---

## 2. Install

Since ggml 0.26 the GPU backends are separate packages that llama.cpp loads at run time. `llama-cpp` on its own is CPU-only and `--list-devices` prints nothing. Install the Vulkan backend with it; it is small and needs only the RADV driver the Arch guide already installed:

```bash
sudo pacman -S --needed llama-cpp ggml-vulkan
llama-server --version
llama-server --list-devices
```

**Check:** `--list-devices` lists your GPU and its memory. Example output for an RX 9070 (device name and free memory will differ):

```
WARNING: radv is not a conformant Vulkan implementation, testing use only.
Available devices:
  Vulkan0: AMD Radeon RX 9070 (RADV GFX1201) (16304 MiB, 15698 MiB free)
```

The warning is Mesa's standard line for a GPU generation it has not yet put through the official conformance suite. It is the same driver that runs your games; ignore it.

The ROCm backend is one more package, but it pulls the ROCm runtime and rocBLAS with it, about 2.6 GB:

```bash
sudo pacman -S --needed ggml-hip             # adds ROCm0 to --list-devices
```

Install it when you want to compare the two backends in step 3; step 2's source build pulls the same runtime anyway. With both installed, `--device` in the launcher picks one, and nothing else changes.

If the device list is empty, Vulkan is not reachable: `vulkaninfo --summary` (package `vulkan-tools`) must show your AMD GPU with the RADV driver. The Arch guide's step 4 installs exactly that; `amdvlk` must not be installed alongside it.

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

Both files are also sets in `scripts/get-models.sh` (`text-swift`, `text-qwen`), which skips what is already on disk. The package's `llama-server` can also download directly with `-hf <repo>:<quant>`; it caches under `~/.cache/llama.cpp`. The explicit file in `~/llm/models` is easier to reason about and to back up.

---

## 4. First run

```bash
llama-server -m ~/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf --alias swift-qwen -ngl 99 -c 16384 -fa on --jinja --port 8080
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

To use this server in Zed, follow [Zed with the local Swift model](../common/03-zed-setup.md). It includes settings for this 16K first run and the tuned launcher below.

For Code OSS's built-in Chat agent, follow [the Custom Endpoint setup](../common/04-code-oss-setup.md).

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
