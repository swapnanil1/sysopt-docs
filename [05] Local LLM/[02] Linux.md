# Linux model server: CachyOS / Arch

[Start here](README.md) · [Network access](common/05-network-access.md) · [Search server](common/06-search-server.md)

**Run these steps on the server.** Clients connect through their editors and do not need the packages, model files, or GPU setup below.

Laid out like the other guides: one file per step in [`linux/`](./linux/), scripts in [`linux/scripts/`](./linux/scripts/), and the OS-independent files in [`common/`](./common/). Step 5 adds images on the same GPU class, with the same kind of runtime and a menu that starts either. Written against llama.cpp `b11514`, ROCm 7.2 from Arch `extra`, CachyOS with `linux-cachyos`, Sway, October 2026.

Recommended baseline for the supplied 27B examples: an RX 9070-class AMD GPU with at least 16 GB VRAM, a Ryzen 5 3600-class CPU or better, and at least 16 GB system RAM. These are guide assumptions, not hard minimums for llama.cpp; smaller models can run on less hardware. Check backend support and adjust the GPU target, context, and thread count for your system. The [Windows guide](./[01]%20Windows.md) covers the equivalent Windows workflow. Benchmark tables are illustrative results for the stated GPU/backend, not a description of the reader’s system or a performance guarantee. Linux Vulkan results and unmeasured ROCm settings are labeled separately.

The two launchers are deliberately not the same. The card-level flags carry over because the kernels are the same; the memory-dependent ones do not, because Linux leaves more of the 16 GB to the model. Step 3 says which is which and what to measure first.

What is different from Windows, in one paragraph: no SDK tarball and no compiler-driver trap, the toolchain is three pacman packages; the distribution ships a ready `llama-cpp` package with the GPU backends as add-on packages (`ggml-vulkan`, `ggml-hip`), so step 1 needs no build at all; memory-mapped loading is the right default; VRAM is not mirrored into host memory, so zram alone is enough and there is no pagefile effect; and there is a choice of two GPU backends (ROCm, Vulkan) on the same binary, which step 2 measures and step 3 pins in one variable.

## Folder layout

```
~/llm/
  llm.sh              menu: text server or an image, with the commands to use each   (step 5)
  start-llm.sh        text launcher; one per model if you add more
  close-llm.sh        stops the server
  gen-image.sh        one image from Qwen-Image 2.1                                  (step 5)
  models/             the text .gguf files
  models/image/       generator, text encoder, VAE, vision projector               (step 5)
  images/             generated images
  logs/               server.log
  scripts/            bench.sh, build-rocm.sh, build-sdcpp.sh, get-models.sh, llm.service
  src/                source builds: llama.cpp (optional, step 2), stable-diffusion.cpp (step 5)
```

The packaged binaries live in `/usr/bin`, the ROCm runtime in `/opt/rocm`. No environment variable is set anywhere; the build script exports `HIPCXX` and `HIP_PATH` for its own run.

## Before you start

- **CHANGE** marks the values that are yours: GPU target, model file, device, context size.
- Step 1 is enough to use a model. Steps 2 and 4 are optional; step 3 is where the speed is.
- Every step ends with a check. If yours doesn't match, stop and fix it before going on.
- **Network default:** all IPv4 interfaces, port 18080, no API key. Use a trusted home LAN without router port forwarding, or launch with `--local`. Configure access using the [network guide](common/05-network-access.md).

## Steps

| # | File | What you do | Time |
|---|---|---|---|
| 1 | [01-setup.md](./linux/01-setup.md) | Install the package, download a model, first run, launcher in place | 10 min + download |
| 2 | [02-build-rocm.md](./linux/02-build-rocm.md) | Optional: build from source for `gfx1201` with ROCm and Vulkan backends, verify, benchmark both | 1 h |
| 3 | [03-launch-and-tuning.md](./linux/03-launch-and-tuning.md) | The launcher flag by flag, Sway keybinding, optional user unit, what to re-measure and how | 20 min |
| 4 | [04-system-tuning.md](./linux/04-system-tuning.md) | What the Arch guide already did, the two GPU knobs that matter, what does nothing | reading |
| 5 | [05-image-generation.md](./linux/05-image-generation.md) | Images: build stable-diffusion.cpp on Vulkan, the four Qwen-Image 2.1 files, first image, editing, the menu | 20 min + 14 GB download |
| + | [common/01-reality-check.md](./common/01-reality-check.md) · [common/02-model-choice-and-speculation.md](./common/02-model-choice-and-speculation.md) | Measured speed vs hosted models; which model and which file, and the speculation trade-off | reading |
| + | [common/03-zed-setup.md](./common/03-zed-setup.md) | Connect Zed to the Swift text server, configure context, check chat and file tools | 5 min |
| + | [common/04-code-oss-setup.md](./common/04-code-oss-setup.md) | Connect Code OSS's built-in agent to llama.cpp; add SearXNG search and page-reading tools | 5 min after server setup |

## Connect clients and add search

After the model runs, complete [network access](common/05-network-access.md). Set up [SearXNG](common/06-search-server.md) on the server if clients need web search, then follow the [Code OSS client](common/04-code-oss-setup.md) or [Zed client](common/03-zed-setup.md) guide on each client device.

## What is in `linux/scripts/`

| File | Goes in | Used in |
|---|---|---|
| `start-llm.sh` | `~/llm` | step 1 and 3: the launcher |
| `close-llm.sh` | `~/llm` | step 3: stops the server |
| `bench.sh` | `~/llm/scripts` | steps 2 and 3: llama-bench with the server's flags, device selectable |
| `build-rocm.sh` | `~/llm/scripts` | step 2: configure and build |
| `llm.service` | `~/.config/systemd/user` | step 3: optional user unit |
| `llm.sh` | `~/llm` | step 5: the menu, text or image, with paste-ready commands |
| `gen-image.sh` | `~/llm` | step 5: one image, with editing and offload switches |
| `build-sdcpp.sh` | `~/llm/scripts` | step 5: clone, configure and build stable-diffusion.cpp with Vulkan |
| `get-models.sh` | `~/llm/scripts` | steps 1 and 5: download a named model set, text or image, with the file names the launchers expect |
