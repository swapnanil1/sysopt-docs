#!/usr/bin/env bash
# llama-bench with the flags the server uses. Prints only the result table.
#   bench.sh MODEL [DEVICE] [PROMPT] [DEPTH] [UBATCH] [KV]
#   bench.sh ~/llm/models/model.gguf ROCm0                          quick check: pp512 / tg64
#   bench.sh ~/llm/models/model.gguf Vulkan0 512,2048 0,16384 512,1024   tuning run (03-launch-and-tuning.md section 4)
set -euo pipefail
BIN=${BIN:-/usr/bin}                 # BIN=$HOME/llm/src/build/bin bench.sh ... for a source build

MODEL=${1:?model path}
DEVICE=${2:-ROCm0}
PROMPT=${3:-512}
DEPTH=${4:-0}
UBATCH=${5:-512}
KV=${6:-q8_0}

echo "=== $BIN/llama-bench  device=$DEVICE ==="
"$BIN/llama-bench" -m "$MODEL" --device "$DEVICE" -ngl 99 -fa 1 -ctk "$KV" -ctv "$KV" \
    -b 2048 -ub "$UBATCH" -t 6 -p "$PROMPT" -n 64 -d "$DEPTH" -r 1 -o md 2>&1 |
    grep -E '^\||Device 0|error|build:'
