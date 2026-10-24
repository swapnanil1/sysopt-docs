# Step 2: Build from source for one GPU (ROCm and Vulkan backends)

## What this step is

Building llama.cpp on CachyOS / Arch with the ROCm (HIP) backend for `gfx1201`, and optionally the Vulkan backend in the same binary, so both can be compared on the same commit. Reasons to do it are listed at the end of step 1; the packaged build is fine otherwise.

Compared with the Windows build this is short: the toolchain is three packages, the compiler driver problem that cost the Windows guide a section does not exist (Linux has no clang-cl), and the build runs in the same folder it is used from.

---

## 1. Dependencies

```bash
sudo pacman -S --needed base-devel cmake ninja git
sudo pacman -S --needed rocm-hip-sdk                         # ROCm 7.2.x in extra: hipcc, clang, rocblas, hipblas, ~5 GB
sudo pacman -S --needed vulkan-headers shaderc glslang        # only for the Vulkan backend; vulkan-radeon is already there
```

ROCm 7.2 supports `gfx1201` natively; no `HSA_OVERRIDE_GFX_VERSION` is needed or wanted. The Arch `rocblas` package ships gfx1201 kernels, which the ROCm backend links against but, on RDNA 4, never calls for quantized models (llama.cpp uses its own MMQ kernels for every batch size, see the Windows build file, section 7.3).

**Check:**

```bash
/opt/rocm/bin/hipconfig --version          # 7.2.x
ls /opt/rocm/lib/rocblas/library | grep -c gfx1201   # > 0
```

Do not add `/opt/rocm/bin` to PATH permanently and do not set `HIP_PATH` globally; the build script sets what it needs for its own run.

---

## 2. Source

```bash
cd ~/llm
git clone https://github.com/ggml-org/llama.cpp src
cd src && git fetch --tags && git checkout b11514       # CHANGE: any tag; newest with: git tag --sort=-v:refname | head -5
```

---

## 3. Build

```bash
~/llm/scripts/build-rocm.sh
```

Which runs, with the variables at its top:

```bash
HIPCXX="$(/opt/rocm/bin/hipconfig -l)/clang" HIP_PATH="$(/opt/rocm/bin/hipconfig -R)" \
cmake -S ~/llm/src -B ~/llm/src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON -DGPU_TARGETS=gfx1201 \          # CHANGE: your target; several: "gfx1201;gfx1100"
  -DGGML_VULKAN=ON \                              # drop to build ROCm only
  -DGGML_NATIVE=ON \                              # -march=native for the CPU-side code
  -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF
cmake --build ~/llm/src/build -j 4
```

Notes on the lines:

- `HIPCXX` points CMake at ROCm's clang, which drives both the host and the device compile. `GPU_TARGETS` is the current name; `AMDGPU_TARGETS` still works with a deprecation warning.
- `GGML_VULKAN=ON` adds the Vulkan backend to the same binary. At run time `--device` picks one; `--list-devices` shows both. Nothing is lost by building both, and step 3 needs both to decide.
- `-j 4`, not `nproc`. The HIP template files need 3 to 5 GB per compiler job. On 16 GB with zram, 4 jobs fit; 6 fail with the compiler killed by the OOM reaper. If a build dies, re-run the script with `JOBS=3`; Ninja resumes where it stopped.
- The Vulkan backend compiles its shaders during the build with `glslc` from `shaderc`. That part is single-threaded and takes a few minutes; it is not stuck.

Allow roughly 25 to 40 minutes on a Ryzen 5 3600-class CPU; build time varies with parallelism, storage, and compiler version, with much of it spent in the HIP backend.

**Check:**

```bash
ls -l ~/llm/src/build/bin/llama-server ~/llm/src/build/bin/llama-bench
~/llm/src/build/bin/llama-server --list-devices        # ROCm0 and, if built, Vulkan0
```

If the build-tree binary is used, the launcher's `BIN=` line is set to `~/llm/src/build/bin`; otherwise it stays `/usr/bin`.

---

## 4. Verify the device code (thirty seconds)

The Windows build had a trap where the GPU kernels silently compiled without optimization. The same check costs nothing here:

```bash
grep -m1 -o 'FLAGS = .*-x hip[^$]*' ~/llm/src/build/build.ninja | grep -o -- '-O[0-3s]'
```

**Check:** `-O3`. If a build ever prints `-O0` or nothing, something overrode `CMAKE_BUILD_TYPE`; delete `build/` and rerun the script.

---

## 5. Two binaries, two backends: know which one is running

After this step there are two llama.cpp installations: the package in `/usr/bin` and the build in `~/llm/src/build/bin`. Each contains both GPU backends. `ROCm0` and `Vulkan0` are device names inside one binary, not separate installs, so a comparison has up to four cells: package or build, times ROCm or Vulkan.

Which binary a script uses is the `BIN=` line at its top, `/usr/bin` by default. For a one-off: `BIN=$HOME/llm/src/build/bin ~/llm/scripts/bench.sh ...`. `bench.sh` prints the full path of the binary before each table.

To check at any moment:

```bash
llama-server --version                               # the package
~/llm/src/build/bin/llama-server --version           # the build: your checkout's tag and commit
curl -s 127.0.0.1:18080/props | grep -o '"build_info":"[^"]*"'   # what the running server was built from
readlink /proc/$(pgrep -x llama-server)/exe          # the file the running process was started from
```

The last two settle it regardless of what any script says.

## 6. Benchmark, both backends

```bash
BIN=$HOME/llm/src/build/bin ~/llm/scripts/bench.sh ~/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf ROCm0
BIN=$HOME/llm/src/build/bin ~/llm/scripts/bench.sh ~/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf Vulkan0
~/llm/scripts/bench.sh ~/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf ROCm0        # the package, for reference
```

Example expectations for the recommended GPU class; replace these with your own measurements:

| | ROCm backend | Vulkan backend |
|---|---|---|
| Prompt processing, pp512 | ~1000 tok/s (Windows measured 1034 on the same kernels) | lower; community reports put Vulkan 30 to 45 % behind on prefill |
| Decode, tg | ~32 tok/s (Windows measured 32.4) | equal or up to ~20 % ahead on RDNA 4 in several reports |
| Flash attention with quantized KV | yes | yes, with a different kernel set; check that `-ctk q8_0` does not fall to a slow path |

For agentic coding, prompt processing dominates wall time, which favours ROCm. For chat, decode dominates, which may favour Vulkan. Step 3 keeps the decision in one variable.

---

## 7. Memory while building

- zram is enough. The compiler's working set compresses well; no swapfile is needed for the build or for running the model.
- A running `llama-server` does not pin host memory for VRAM the way it does on Windows, so building while serving is possible on 16 GB. It is still slower and competes for the page cache; stop the server for a full rebuild.

---

## 8. Updating

```bash
~/llm/close-llm.sh
cd ~/llm/src && git fetch --tags && git checkout b12000     # CHANGE
~/llm/scripts/build-rocm.sh                                  # incremental; Ninja rebuilds only what changed
```

Then section 4 and one `bench.sh` run. A `pacman -Syu` that moves `rocm-hip-sdk` to a new major version needs a clean `build/` afterwards.
