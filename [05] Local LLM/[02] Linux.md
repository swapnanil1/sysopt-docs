# llama.cpp on an AMD GPU under CachyOS / Arch: a model in ten minutes, then the build, then the tuning

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
- **Network default:** the text server listens on all IPv4 interfaces at port 18080, without an API key. This applies to the first-run command, `start-llm.sh`, the text menu, the Sway shortcut, and the systemd user unit. Use `http://127.0.0.1:18080` on the PC or `http://<PC-LAN-IP>:18080` from a laptop. This assumes a trusted home LAN; do not forward the port through your router. For localhost only, run `start-llm.sh --local`. See [laptop setup](./linux/03-launch-and-tuning.md#use-the-pcs-model-from-a-laptop).

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
| + | [common/04-code-oss-setup.md](./common/04-code-oss-setup.md) | Connect Code OSS's built-in agent to llama.cpp; add SearXNG search and page-reading tools | 5 min + search setup |

## Use the model and search from a laptop

Run the model launcher and the [SearXNG container](./common/04-code-oss-setup.md#4-optional-add-free-local-web-search) on the PC. Run your editor and its MCP adapter on the laptop, with the project open there. The PC handles inference and search queries; the laptop performs file edits, terminal commands, and page fetching through its tools.

Find the PC's Ethernet/Wi-Fi IPv4 address with `ip -br -4 address show scope global`, then use it in these settings:

| Laptop setting | Address |
|---|---|
| Code OSS model request URL | `http://<PC-LAN-IP>:18080/v1/chat/completions` |
| Zed `api_url` | `http://<PC-LAN-IP>:18080` |
| Code's search MCP `SEARXNG_URL` | `http://<PC-LAN-IP>:8888` |

The model ID is `swift-qwen`. Neither service requires an API key; use `local` only if the editor requires a placeholder. Each laptop using the search MCP adapter needs Node.js 22+ and npm. Verify the model with [the LAN checks](./linux/03-launch-and-tuning.md#use-the-pcs-model-from-a-laptop) and search with [an actual search and page read](./common/04-code-oss-setup.md#d-check-that-swift-searches-and-reads-a-page). Both ports must be reachable from the laptop on the trusted LAN.

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
