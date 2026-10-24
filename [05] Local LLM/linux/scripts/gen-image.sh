#!/usr/bin/env bash
# One image with stable-diffusion.cpp (Vulkan). Lives in ~/llm next to start-llm.sh.
#   gen-image.sh "prompt" [out.png] [WxH] [steps] [seed]
#   PRESET=zimage gen-image.sh "prompt"                        another model set (qwen, zimage, flux3; see get-models.sh)
#   REF=picture.png gen-image.sh "what to change" out.png      edits the picture instead (needs the preset's MMPROJ)
#   OFFLOAD=1 gen-image.sh ...                                 keeps extra weights in RAM when VRAM runs out
# CHANGE: the MODEL line of a preset if you use another GGUF of that model. Encoder, VAE and settings are per model.
set -euo pipefail

ROOT="$HOME/llm"
IMG="$ROOT/models/image"
BIN="$ROOT/src/stable-diffusion.cpp/build/bin"
PRESET=${PRESET:-qwen}

case "$PRESET" in
  qwen)    # Qwen-Image 2.1: the default. 20 steps, cfg 6. get-models.sh image-qwen
    MODEL="$IMG/qwen_image_2.1-Q8_0.gguf"                   # CHANGE for another Qwen-Image 2.1 GGUF
    LLM="$IMG/Qwen3VL-8B-Instruct-Q4_K_M.gguf"
    VAE="$IMG/qwen_image_2.1_vae_bf16.safetensors"          # the 2.1 VAE; 1.0 and Wan VAEs do not work
    MMPROJ="$IMG/mmproj-Qwen3VL-8B-Instruct-Q8_0.gguf"
    CFG=6.0; DEF_STEPS=20; EXTRA=() ;;
  zimage)  # Z-Image Turbo: 8 steps, cfg 1, no editing. get-models.sh image-zimage
    MODEL="$IMG/z_image_turbo-Q8_0.gguf"
    LLM="$IMG/Qwen3-4B-Instruct-2507-Q8_0.gguf"
    VAE="$IMG/ae.safetensors"
    MMPROJ=""
    CFG=1.0; DEF_STEPS=8; EXTRA=() ;;
  flux3)   # FLUX.3 Image Klein: 16 steps, cfg 1, editing with up to 10 references. get-models.sh image-flux3
    MODEL="$IMG/flux3-image-klein-Q8_0.gguf"
    LLM="$IMG/Qwen3VL-4B-Instruct-Q4_K_M.gguf"
    VAE="$IMG/flux2-vae.safetensors"
    MMPROJ="$IMG/mmproj-Qwen3VL-4B-Instruct-Q8_0.gguf"
    CFG=1.0; DEF_STEPS=16; EXTRA=() ;;
  *) echo "unknown PRESET=$PRESET (qwen, zimage, flux3)" >&2; exit 1 ;;
esac

PROMPT=${1:?usage: gen-image.sh "prompt" [out.png] [WxH] [steps] [seed]}
OUT=${2:-$ROOT/images/$(date +%Y%m%d-%H%M%S).png}
SIZE=${3:-1024x1024}
STEPS=${4:-$DEF_STEPS}
SEED=${5:--1}
W=${SIZE%x*}; H=${SIZE#*x}

if ss -ltn 'sport = :18080' | grep -q LISTEN; then
    echo "llama-server is running and holds most of the VRAM. Run ~/llm/close-llm.sh first." >&2
    exit 1
fi
mkdir -p "$(dirname "$OUT")"

args=(
  --diffusion-model "$MODEL" --llm "$LLM" --vae "$VAE"
  -p "$PROMPT"
  --cfg-scale "$CFG" --steps "$STEPS" --sampling-method euler "${EXTRA[@]}"
  -W "$W" -H "$H" --seed "$SEED"
  -o "$OUT" -v
)
if [ -n "${REF:-}" ]; then
    [ -n "$MMPROJ" ] || { echo "PRESET=$PRESET has no vision projector; it cannot edit pictures" >&2; exit 1; }
    args+=(--llm_vision "$MMPROJ" -r "$REF")
fi
[ "${OFFLOAD:-0}" = 1 ] && args+=(--offload-to-cpu)

exec "$BIN/sd-cli" "${args[@]}"
