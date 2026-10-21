#!/usr/bin/env bash
# Builds stable-diffusion.cpp with the Vulkan backend into ~/llm/src/stable-diffusion.cpp/build.
# No ROCm, no Python: the same shape as the llama.cpp source build. Re-run to update; it pulls first.
set -euo pipefail
ROOT="$HOME/llm"
SRC="$ROOT/src/stable-diffusion.cpp"

sudo pacman -S --needed base-devel cmake ninja git libwebp vulkan-headers shaderc spirv-headers

if [ -d "$SRC/.git" ]; then
    git -C "$SRC" pull --ff-only
    git -C "$SRC" submodule update --init --recursive
else
    mkdir -p "$ROOT/src"
    git clone --recursive https://github.com/leejet/stable-diffusion.cpp "$SRC"
fi

cmake -G Ninja -B "$SRC/build" -S "$SRC" \
  -DCMAKE_BUILD_TYPE=Release \
  -DSD_VULKAN=ON \
  -DSD_USE_SYSTEM_WEBP=ON
ninja -C "$SRC/build"

echo
ls -l "$SRC/build/bin/"
git -C "$SRC" log -1 --format='built %h from %cd' --date=short
