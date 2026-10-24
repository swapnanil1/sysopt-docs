# Step 5: Images on the same GPU class with stable-diffusion.cpp

## What this step is

The image counterpart of steps 1 to 3: one C++ binary with a Vulkan backend, three model files, one wrapper script, and a menu that starts either the text server or an image. No ROCm, no Python, nothing under pacman's control. Written against stable-diffusion.cpp commit `b13a482` (October 18 2026) and Qwen-Image 2.1, targeting an RX 9070-class GPU with at least 16 GB VRAM.

**Measured and unmeasured.** The build and file list describe an example Vulkan setup. Measure the memory budget on your GPU. The time per image is not measured yet; the line that says so is marked.

---

## 1. Why this runtime and not ComfyUI

ComfyUI is the usual image tool and it runs on a GPU in the recommended class, but on Arch it means PyTorch for ROCm, which pulls the whole ROCm SDK: 96 packages, 34 GB under `/usr`, on the root subvolume Timeshift snapshots. Every ROCm update rewrites most of it and every snapshot that straddles an update keeps the old copy. The alternative is a venv with AMD's wheels, which works but is a second Python stack to maintain.

stable-diffusion.cpp is to images what llama.cpp is to text: the same ggml library, the same GGUF files, the same Vulkan backend you already run the text model on. It supports Qwen-Image 2.1 since the day that model came out, plus FLUX, Z-Image and most of the 2026 open releases. What it lacks is the node editor; for one prompt in, one image out, it is the right tool.

---

## 2. Build

```bash
cp scripts/build-sdcpp.sh ~/llm/scripts/ && chmod +x ~/llm/scripts/build-sdcpp.sh
~/llm/scripts/build-sdcpp.sh
```

The script installs the toolchain and the three Vulkan header packages, clones the source with its submodules into `~/llm/src/stable-diffusion.cpp`, configures with `SD_VULKAN=ON`, and builds. Build time depends on CPU and parallelism; shader compilation accounts for much of it. Re-running it pulls and rebuilds.

**Check:** the last lines list `sd-cli` and `sd-server` in `build/bin/` with the commit they were built from.

What it needs that the Arch guide did not install: `base-devel` (no compiler is on a minimal install), `vulkan-headers`, `shaderc`, `spirv-headers`. The configure step says exactly which one is missing if any is, and the answer is always one of those four. The warning about `pnpm` is the optional web UI for `sd-server`; ignore it.

---

## 3. Which model, and the four files

Qwen-Image 2.1 is the top open-weight model on the Artificial Analysis arena as of October 2026, ahead of everything that fits 16 GB and most of what does not. It is a 7B generator with an 8B Qwen3-VL text encoder, native 2K, legible text in images, editing with up to ten reference images. Licence: Qwen Research, non-commercial. The next model down that fits is Z-Image Turbo, 8 steps instead of 20 and Apache 2.0, about 90 Elo behind.

An image model is three files that run in sequence, plus one optional:

| Role | File | Size | Source |
|---|---|---|---|
| generator | `qwen_image_2.1-Q8_0.gguf` | 7.7 GB | `leejet/Qwen-Image-2.1-GGUF` |
| text encoder | `Qwen3VL-8B-Instruct-Q4_K_M.gguf` | 5.0 GB | `Qwen/Qwen3-VL-8B-Instruct-GGUF` |
| VAE | `qwen_image_2.1_vae_bf16.safetensors` | 0.7 GB | `Comfy-Org/Qwen-Image-2.1`, folder `vae` |
| vision projector | `mmproj-Qwen3VL-8B-Instruct-Q8_0.gguf` | 0.75 GB | same repo as the encoder; only for editing |

```bash
mkdir -p ~/llm/models/image && cd ~/llm/models/image
curl -L -O 'https://huggingface.co/leejet/Qwen-Image-2.1-GGUF/resolve/main/qwen_image_2.1-Q8_0.gguf'
curl -L -O 'https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3VL-8B-Instruct-Q4_K_M.gguf'
curl -L -O 'https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors'
curl -L -O 'https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-8B-Instruct-Q8_0.gguf'
ls -l --block-size=M
```

Why these quants: the budget is weights plus about 2 GB of working buffers at 1024², under a 15.3 GB ceiling. Q8 on the generator (7.7 GB) with Q4 on the encoder (5.0 GB) lands at about 15 GB resident. Q8 on both would spill. Quantization loss is visible on the generator before it is on the encoder, so the generator gets the bits. The Q6_K generator (6.0 GB) is the fallback if the machine has less headroom; the difference is hard to see.

Or, instead of the four curl lines, the set downloader, which skips files already on disk and names each file the way the wrapper expects:

```bash
cp scripts/get-models.sh ~/llm/scripts/ && chmod +x ~/llm/scripts/get-models.sh
~/llm/scripts/get-models.sh               # lists the sets and what is on disk
~/llm/scripts/get-models.sh image-qwen
```

### The other sets that fit

Three image sets are wired into the wrapper as presets, so switching is one variable, not four edited lines:

| Set | Model | Files | Steps, CFG | Licence | When |
|---|---|---|---|---|---|
| `image-qwen` | Qwen-Image 2.1, 7B | Q8 generator 7.7 GB, Qwen3-VL 8B encoder 5 GB, VAE, projector | 20, 6.0 | Qwen Research, non-commercial | the default: quality, text in images, editing |
| `image-zimage` | Z-Image Turbo, 6B | Q8 generator 6.6 GB, Qwen3-4B encoder 4.3 GB, Flux VAE | 8, 1.0 | Apache 2.0 | speed, about a fifth of the time per image; no editing |
| `image-flux3` | FLUX.3 Image Klein, 5.6B | Q8 generator 6.2 GB, Qwen3-VL 4B encoder 2.5 GB, FLUX.2 VAE, projector | 16, 1.0 | FLUX Kommunity, free under 5 M revenue | released October 15 2026; the maker claims first place by internal evals, no arena score yet |

```bash
~/llm/scripts/get-models.sh image-zimage
PRESET=zimage ~/llm/gen-image.sh "a lovely cat holding a sign that says 'hello'"
PRESET=zimage ~/llm/llm.sh                 # the menu's image screen follows the preset too
```

The sets share nothing: each model has its own encoder and VAE. All three sets together are about 36 GB. The text sets are in the same script, `text-swift` and `text-qwen`, for a fresh machine. No Turbo GGUF of Qwen-Image 2.1 exists at the time of writing; when one appears it takes the `qwen` preset with `--sigmas qwen-image-2.1-turbo --steps 8 --cfg-scale 1.0` on the raw command.

Any other Qwen-Image 2.1 GGUF, including community fine-tunes and merges, is a drop-in: same encoder, same VAE, same flags. Only the `MODEL=` line in the wrapper changes. The 1.0 VAE and the Wan VAE are not interchangeable with the 2.1 VAE.

---

## 4. First image

```bash
cp scripts/gen-image.sh ~/llm/ && chmod +x ~/llm/gen-image.sh
~/llm/close-llm.sh                      # the text server holds the VRAM; stop it first
time ~/llm/gen-image.sh "a lovely cat holding a sign that says 'hello'" ~/llm/images/first.png 1024x1024 20 42
```

The wrapper runs `sd-cli` with the doc's settings for this model: euler, CFG 6.0, 20 steps, the four files above, `-v` so the per-step time and memory are printed. Arguments after the prompt are optional: output path, size, steps, seed. Seed `-1` is random. Sizes must be divisible by 32.

**Check:** `-v` prints each component's memory and a total before sampling. Under about 15 300 MiB it runs resident. If it aborts on allocation, `OFFLOAD=1` in front of the command keeps the extra weights in RAM and streams them, slower, same output.

**Not measured yet:** time per image at 1024², 20 steps, with the Q8 generator. Measure it on your GPU and record the `-v` memory total locally.

Then the raw command, for anything the wrapper does not expose:

```bash
~/llm/src/stable-diffusion.cpp/build/bin/sd-cli \
  --diffusion-model ~/llm/models/image/qwen_image_2.1-Q8_0.gguf \
  --llm ~/llm/models/image/Qwen3VL-8B-Instruct-Q4_K_M.gguf \
  --vae ~/llm/models/image/qwen_image_2.1_vae_bf16.safetensors \
  -p "a lovely cat holding a sign that says 'hello'" \
  --cfg-scale 6.0 --steps 20 --sampling-method euler -W 1024 -H 1024 --seed 42 -v \
  -o ~/llm/images/first.png
```

`sd-cli --help` lists the rest: negative prompt, `--flow-shift`, `--sigmas qwen-image-2.1-turbo` for the Turbo weights, LoRA loading, highres fix, tiling for large outputs.

---

## 5. Editing a picture

The vision projector lets the encoder see a reference image, and the prompt becomes an instruction instead of a description:

```bash
REF=~/llm/images/first.png ~/llm/gen-image.sh "change the sign to say 'bye'" ~/llm/images/first-edit.png
```

Several references: use the raw command with `-r a.png -r b.png`, in the order they are referred to. For transparent output, start the prompt with `This is an RGBA image with transparency.` and end with `The image has alpha channel and the background is transparent.`; the model decides on alpha from the prompt, and only PNG and WebP keep it.

---

## 6. The menu

`llm.sh` is one screen that knows both tracks:

```bash
cp scripts/llm.sh ~/llm/ && chmod +x ~/llm/llm.sh
~/llm/llm.sh
```

Option 1 shows the text model, its device, context, memory need and whether it is running, then the curl commands to talk to it, then offers to start or stop it. Option 2 shows the four image files with sizes, the memory need, the wrapper commands and the raw command, then offers to generate one image with a prompt, size and steps typed in. Option 3 is VRAM, running state and what is on disk. It reads the model names from the two scripts, so a changed `MODEL=` line shows up without editing the menu. Nothing starts until the question is answered with `y`.

The two tracks do not run at the same time on 16 GB. The image wrapper refuses to start while the text server holds port 18080, and the menu says which one is up.

---

## 7. What is kept, and what leaves the machine

Nothing leaves. The binary has no network code in the generation path, the model files are weight tensors with no code, and no API is involved. The downloads were the only network event.

Three things are written locally per image: the PNG; the prompt, seed, steps and model name inside the PNG's text chunks, which travel with the file if you share it (`mogrify -strip image.png`, package `imagemagick`, removes them); and the shell line in your history. The model keeps nothing between runs.

---

## 8. Folder, after this step

```
~/llm/
  llm.sh              the menu
  start-llm.sh        text server launcher          (step 1, 3)
  close-llm.sh        stops it
  gen-image.sh        one image                      (this step)
  models/             text .gguf files
  models/image/       the four image files
  images/             output
  logs/               server.log
  scripts/            bench.sh, build-rocm.sh, build-sdcpp.sh, get-models.sh, llm.service
  src/                llama.cpp (optional, step 2) and stable-diffusion.cpp
```
