#!/usr/bin/env bash
# Configure + build llama.cpp with the ROCm (HIP) backend for one GPU target, plus the Vulkan backend.
# Needs: rocm-hip-sdk, cmake, ninja, base-devel; vulkan-headers shaderc glslang for Vulkan (02-build-rocm.md).
# CHANGE: GPU for your card, VULKAN=OFF to skip the Vulkan backend, JOBS=3 if the build runs out of memory.
set -euo pipefail

SRC="$HOME/llm/src"
OUT="$SRC/build"
GPU=gfx1201
VULKAN=ON
JOBS=${JOBS:-4}                     # 3-5 GB of RAM per HIP compiler job; 4 fits in 16 GB with zram

ROCM=/opt/rocm
export HIPCXX="$("$ROCM/bin/hipconfig" -l)/clang"
export HIP_PATH="$("$ROCM/bin/hipconfig" -R)"

cmake -S "$SRC" -B "$OUT" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON -DGPU_TARGETS="$GPU" \
  -DGGML_VULKAN="$VULKAN" \
  -DGGML_NATIVE=ON \
  -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF

cmake --build "$OUT" -j "$JOBS"

echo
echo "device compile flags:"
grep -m1 -o 'FLAGS = .*-x hip[^$]*' "$OUT/build.ninja" | grep -o -- '-O[0-3s]' || echo "(no -O found: check CMAKE_BUILD_TYPE)"
"$OUT/bin/llama-server" --list-devices
