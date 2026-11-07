# Step 2: Build llama.cpp with ROCm on Arch

[Linux overview](../%5B02%5D%20Linux.md) · [Launcher and measurements](03-launch-and-tuning.md)

This is the source-build route. You can use it without installing the distribution's `llama-cpp` package. Commands use **gfx1201 as an example GPU target**, not a detected hardware requirement. Choose the target for your GPU and verify that your ROCm version supports it. Vulkan is optional.

## 1. Install the dependencies you need

```bash
sudo pacman -Syu --needed base-devel cmake ninja git openssl hip-runtime-amd hipblas rocblas
```

Pacman resolves the required ROCm compiler, device libraries, and runtime dependencies. The full `rocm-hip-sdk` metapackage is not necessary for this build and may pull substantially more libraries. Review pacman's transaction totals before confirming; download and installed sizes depend on package versions and existing dependencies.

```bash
/opt/rocm/bin/hipconfig --version
/opt/rocm/bin/rocm_agent_enumerator
```

Match the enumerated GPU target to the build configuration; for example, `gfx1201` corresponds to an RX 9070-class target. Prefer a ROCm release with native support instead of adding an `HSA_OVERRIDE_GFX_VERSION` workaround. Do not persist global ROCm environment overrides.

Only if you also want a Vulkan backend:

```bash
sudo pacman -Syu --needed vulkan-radeon vulkan-headers shaderc spirv-headers
```

## 2. Create folders and clone Git source

```bash
mkdir -p "$HOME/llm"/{models,logs,scripts}
git clone https://github.com/ggml-org/llama.cpp.git "$HOME/llm/src"
git -C "$HOME/llm/src" rev-parse HEAD
```

The clone uses the current default branch. Record the commit because flags and model support change. If `~/llm/src` already contains a checkout, inspect `git -C "$HOME/llm/src" status` before updating it; do not clone over it. Put your downloaded GGUF in `~/llm/models/`; keep all split-model parts together.

## 3. Configure and build without a wrapper

Paste the whole configuration block. Comments are outside the continued command so it can be copied directly:

```bash
HIPCXX="$(/opt/rocm/bin/hipconfig -l)/clang" \
HIP_PATH="$(/opt/rocm/bin/hipconfig -R)" \
cmake -S "$HOME/llm/src" -B "$HOME/llm/src/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_HIP_FLAGS="--rocm-path=/opt/rocm --hip-path=/opt/rocm" \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx1201 \
  -DGGML_VULKAN=OFF \
  -DGGML_NATIVE=ON \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_TOOLS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF
```

Continue only after configuration succeeds:

```bash
cmake --build "$HOME/llm/src/build" --parallel 2
```

`Release` enables compiler optimization; inspect the generated HIP command to verify it. `GPU_TARGETS` selects the example GPU target and `GGML_NATIVE` targets the CPU doing the build. Build parallelism affects compilation time and RAM consumption, not the finished model's token speed. Two jobs are a conservative starting point; choose parallelism according to available RAM, because HIP compilation can use several GiB per job. If the compiler is killed for lack of memory, resume with `--parallel 1` rather than discarding completed work. Stop inference before building.

To include Vulkan, install its dependencies and change `-DGGML_VULKAN=OFF` to `ON` before configuring. A ROCm-only build cannot run `Vulkan0` benchmarks.

### Troubleshooting: HIP header not found

A build can pass configuration and then fail when compiling a HIP source with:

```text
fatal error: 'hip/hip_fp16.h' file not found
```

First check whether `/opt/rocm/include/hip/hip_fp16.h` exists. The manual command sets `HIP_PATH` only for configuration, not for a later, separately invoked build. If the header exists but compiler discovery fails, save explicit paths in CMake:

```bash
cmake -S "$HOME/llm/src" -B "$HOME/llm/src/build" \
  -DCMAKE_HIP_FLAGS="--rocm-path=/opt/rocm --hip-path=/opt/rocm"
cmake --build "$HOME/llm/src/build" --parallel 2
```

When the header is already installed, try the path correction before installing a larger SDK or discarding the build directory. This configuration updates the HIP flags; preserve any additional custom HIP flags if you have added your own. The [upstream HIP build instructions](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#hip) and [Clang path options](https://clang.llvm.org/docs/HIPSupport.html) describe the toolchain settings.

### Optional wrapper

The repository's `build-rocm.sh` contains the same persistent path fix and defaults to ROCm-only, two jobs. Copy it from an explicit repository path:

```bash
LLM_DOCS="/path/to/sysopt-docs/[05] Local LLM"
cp "$LLM_DOCS/linux/scripts/build-rocm.sh" "$HOME/llm/scripts/"
chmod +x "$HOME/llm/scripts/build-rocm.sh"
~/llm/scripts/build-rocm.sh
```

For an optional dual-backend build: `JOBS=2 VULKAN=ON ~/llm/scripts/build-rocm.sh`.

## 4. Verify the binary and optimization

```bash
"$HOME/llm/src/build/bin/llama-server" --version
"$HOME/llm/src/build/bin/llama-server" --list-devices
```

Expect `ROCm0` followed by your device name and available memory. GNU in `--version` describes the host build; it does not mean HIP kernels were compiled by GCC.

Inspect a generated HIP compiler command without executing it:

```bash
ninja -C "$HOME/llm/src/build" -t commands | awk '/ -x hip / && !seen { seen=1; for (i=1; i<=NF; i++) if ($i ~ /^-O[0-3sz]$/) print $i }'
```

Expect `-O3` for this release configuration. Missing output is a reason to inspect the generated commands and cache, not proof that the build is unoptimized. The older check searching for `-x hip` on a Ninja `FLAGS =` line can miss it because Ninja keeps parts of the command separately.

A missing `ccache` warning concerns optional tooling, not a build failure. C++ deprecation warnings may be nonfatal. If a UI asset download falls back from a pinned tag to another release, inspect whether verification and extraction succeed. Check the final build exit status rather than treating every warning as fatal.

## 5. Select the correct executable

Copy the launcher and benchmark script as directed in [step 1](01-setup.md#5-put-the-launcher-in-place). The updated scripts prefer `~/llm/src/build/bin` when its executable exists and otherwise use `/usr/bin`. They print the selected binary path. `BIN=/usr/bin ~/llm/start-llm.sh` explicitly selects a packaged install if present.

For an older installed launcher that reports `/usr/bin/llama-server: No such file or directory`, set its `BIN` line to:

```bash
BIN="$HOME/llm/src/build/bin"
```

A source install does not also require a package install. Likewise, a ROCm-only binary does not include Vulkan just because a Vulkan driver is installed.

## 6. Benchmark and update

Follow [step 3](03-launch-and-tuning.md) for reproducible prefill/decode tests, an MTP request, and memory checks. Stop the server before `llama-bench`. It measures synthetic inputs and does not measure the server's MTP acceleration.

To update an existing clean checkout, inspect it, pull, reconfigure with the same flags, and rebuild. Do not overwrite uncommitted changes. After a major ROCm/toolchain change, use a fresh build directory if required; rerun device detection and the benchmark before relying on earlier results.
