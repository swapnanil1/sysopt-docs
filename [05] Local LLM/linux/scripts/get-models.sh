#!/usr/bin/env bash
# Downloads a named model set into ~/llm/models, with the file names the launchers expect.
#   get-models.sh                 lists the sets and what is already on disk
#   get-models.sh image-qwen      one set; several names in one go are fine
# Sets target GPUs with at least 16 GB VRAM; fit depends on context, resolution and flags. Sizes are rounded.
# Sets marked (token) are gated on Hugging Face: accept the terms in a browser once, then
# export HF_TOKEN=hf_... from your account settings before running.
set -euo pipefail
ROOT="$HOME/llm"
M="$ROOT/models"; I="$M/image"
HF=https://huggingface.co

declare -A DESC=(
  [text-swift]="Swift 1.5 Qwen3.8-27B, GSQ-RCO IQ3_S with draft head, 12 GB. The launcher default; fewer thinking tokens (token)"
  [text-qwen]="Qwen3.8-27B, same quant and draft head, 12 GB. The plain twin for maths-heavy or instruction-exact work"
  [image-qwen]="Qwen-Image 2.1: Q8 generator 7.7 GB, Qwen3-VL 8B encoder 5 GB, VAE, projector. Top open-weight model; 20 steps"
  [image-zimage]="Z-Image Turbo: Q8 generator 6.6 GB, Qwen3-4B encoder 4.3 GB, Flux VAE. 8 steps, Apache 2.0, the fast one"
  [image-flux3]="FLUX.3 Image Klein: Q8 generator 6.2 GB, Qwen3-VL 4B encoder 2.5 GB, FLUX.2 VAE. 16 steps, Kommunity licence"
)

get() {  # get <dir> <url> [header]
    local dir=$1 url=$2 f; f="$dir/$(basename "$url")"
    mkdir -p "$dir"
    if [ -s "$f" ]; then echo "have   $(basename "$f")"; return; fi
    echo "fetch  $(basename "$f")"
    if [ -n "${3:-}" ]; then curl -fL --progress-bar -H "$3" -o "$f.part" "$url"; else curl -fL --progress-bar -o "$f.part" "$url"; fi
    mv "$f.part" "$f"
}
auth() { [ -n "${HF_TOKEN:-}" ] || { echo "this set is gated: export HF_TOKEN=hf_... first" >&2; exit 1; }; echo "Authorization: Bearer $HF_TOKEN"; }

set_text-swift() {
    get "$M" "$HF/ukisai/Swift-1.5-Qwen3.8-27B-GSQ-RCO-GGUF/resolve/main/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" "$(auth)"
    echo "launcher: MODEL=\$ROOT/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf   (start-llm.sh default)"
}
set_text-qwen() {
    get "$M" "$HF/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/resolve/main/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
    echo "launcher: MODEL=\$ROOT/models/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
}
set_image-qwen() {
    get "$I" "$HF/leejet/Qwen-Image-2.1-GGUF/resolve/main/qwen_image_2.1-Q8_0.gguf"
    get "$I" "$HF/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3VL-8B-Instruct-Q4_K_M.gguf"
    get "$I" "$HF/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors"
    get "$I" "$HF/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-8B-Instruct-Q8_0.gguf"
    echo "use: ~/llm/gen-image.sh \"prompt\"            (PRESET=qwen is the default)"
}
set_image-zimage() {
    get "$I" "$HF/leejet/Z-Image-Turbo-GGUF/resolve/main/z_image_turbo-Q8_0.gguf"
    get "$I" "$HF/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q8_0.gguf"
    get "$I" "$HF/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"
    echo "use: PRESET=zimage ~/llm/gen-image.sh \"prompt\""
}
set_image-flux3() {
    get "$I" "$HF/leejet/flux-3-image-klein-GGUF/resolve/main/flux3-image-klein-Q8_0.gguf"
    get "$I" "$HF/Qwen/Qwen3-VL-4B-Instruct-GGUF/resolve/main/Qwen3VL-4B-Instruct-Q4_K_M.gguf"
    get "$I" "$HF/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"
    get "$I" "$HF/Qwen/Qwen3-VL-4B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-4B-Instruct-Q8_0.gguf"
    echo "use: PRESET=flux3 ~/llm/gen-image.sh \"prompt\""
}

if [ $# -eq 0 ]; then
    for k in text-swift text-qwen image-qwen image-zimage image-flux3; do printf '  %-13s %s\n' "$k" "${DESC[$k]}"; done
    echo; echo "on disk:"; ls -l --block-size=G "$M"/*.gguf "$I"/* 2>/dev/null | awk '{printf "  %5s  %s\n", $5, $9}' | sed "s#$M/##"
    exit 0
fi
for s in "$@"; do
    [ -n "${DESC[$s]:-}" ] || { echo "unknown set: $s" >&2; exit 1; }
    echo "== $s: ${DESC[$s]}"; "set_$s"; echo
done
