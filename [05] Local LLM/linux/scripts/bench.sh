#!/usr/bin/env bash
# Non-MTP baseline: server batch/KV settings, six CPU threads.
# llama-bench has no separate -tb option; validate -t 6 -tb 12 with server requests.
#   bench.sh MODEL [DEVICE] [PROMPT] [DEPTH] [UBATCH] [KV]
#   bench.sh ~/llm/models/model.gguf ROCm0                          pp2048 / tg128, 3 repeats
#   bench.sh ~/llm/models/model.gguf Vulkan0 512,2048 0,16384 512,1024   tuning run (03-launch-and-tuning.md section 3)
set -euo pipefail
if [[ -x "$HOME/llm/src/build/bin/llama-bench" ]]; then
    DEFAULT_BIN="$HOME/llm/src/build/bin"
else
    DEFAULT_BIN=/usr/bin
fi
BIN=${BIN:-$DEFAULT_BIN}

MODEL=${1:?model path}
DEVICE=${2:-ROCm0}
PROMPT=${3:-2048}
DEPTH=${4:-0}
UBATCH=${5:-512}
KV=${6:-q8_0}

if pgrep -u "$(id -u)" -x llama-server >/dev/null; then
    echo "Stop your llama-server before benchmarking; both would compete for VRAM." >&2
    exit 1
fi
echo "=== $BIN/llama-bench  device=$DEVICE ==="
"$BIN/llama-bench" -m "$MODEL" --device "$DEVICE" -ngl 99 -fa on -ctk "$KV" -ctv "$KV" \
    -b 2048 -ub "$UBATCH" -t 6 -p "$PROMPT" -n 128 -d "$DEPTH" -r 3 -o md
