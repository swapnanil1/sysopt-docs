#!/usr/bin/env bash
# Configure + build llama.cpp with ROCm; VULKAN=ON adds the optional Vulkan backend.
# Needs: hip-runtime-amd, hipblas, rocblas, cmake, ninja, base-devel, git, openssl.
# Vulkan also needs vulkan-radeon, vulkan-headers, shaderc and spirv-headers.
# Example: JOBS=4 VULKAN=ON ./build-rocm.sh. Build jobs do not affect inference speed.
set -euo pipefail

SRC="$HOME/llm/src"
OUT="$SRC/build"
GPU=${GPU:-gfx1201}
VULKAN=${VULKAN:-OFF}
JOBS=${JOBS:-2}                     # conservative for 16 GB RAM; reduce to 1 on OOM

ROCM=/opt/rocm
export HIPCXX="$("$ROCM/bin/hipconfig" -l)/clang"
export HIP_PATH="$("$ROCM/bin/hipconfig" -R)"

cmake -S "$SRC" -B "$OUT" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_HIP_FLAGS="--rocm-path=$ROCM --hip-path=$ROCM" \
  -DGGML_HIP=ON -DGPU_TARGETS="$GPU" \
  -DGGML_VULKAN="$VULKAN" \
  -DGGML_NATIVE=ON \
  -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF

cmake --build "$OUT" -j "$JOBS"

echo
echo "device compile flags:"
ninja -C "$OUT" -t commands | awk '/ -x hip / && !seen { seen=1; for (i=1; i<=NF; i++) if ($i ~ /^-O[0-3sz]$/) print $i } END { if (!seen) print "No HIP compile command found; inspect the generated build before judging optimization." }'
"$OUT/bin/llama-server" --list-devices
