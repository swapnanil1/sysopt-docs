#!/usr/bin/env bash
# Launcher for llama-server. Lives in ~/llm next to models/, logs/ and scripts/.
# One copy per model: duplicate, rename, change MODEL= and the per-model flags (03-launch-and-tuning.md).
# CHANGE: MODEL, DEVICE, and the per-model flags (-c, -ctk/-ctv, --no-reasoning-preserve, --spec-type). The rest is machine-wide.
# The -mtp file carries the model's own draft head; --spec-type draft-mtp uses it. A file without the
# head needs --spec-type ngram-mod instead, and then -c 65536 fits.
# The sampling line is the model card's setting; a client that sends its own values overrides it.
set -euo pipefail

ROOT="$HOME/llm"
BIN=/usr/bin                                   # or "$ROOT/src/build/bin" after a source build (02-build-rocm.md)
MODEL="$ROOT/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
DEVICE=ROCm0                                   # ROCm0 or Vulkan0; see: "$BIN/llama-server" --list-devices
PORT=8080

if ss -ltn "sport = :$PORT" | grep -q LISTEN; then
    echo "Something is already listening on port $PORT:"
    ss -ltnp "sport = :$PORT"
    echo "If it is llama-server, run close-llm.sh first."
    exit 1
fi

mkdir -p "$ROOT/logs"
# Qwen3.5/3.8 files carry 96 small BF16 tensors that go through rocBLAS. On the Windows SDK rocBLAS forwards
# them to hipBLASLt, which crashes on gfx1201; 0 makes rocBLAS use its own kernels. Not confirmed needed on
# Linux ROCm 7.2, harmless if not. Ignored by the Vulkan backend.
export ROCBLAS_USE_HIPBLASLT=0
exec "$BIN/llama-server" \
  -m "$MODEL" \
  --device "$DEVICE" \
  -ngl 99 -c 49152 -np 1 -n 16384 -b 1024 -ub 512 -t 6 \
  -fa on -ctk q8_0 -ctv q8_0 --jinja \
  --no-reasoning-preserve --no-context-shift \
  --timeout 600 --threads-http 2 --port "$PORT" \
  --cache-ram 0 \
  --spec-type draft-mtp --spec-draft-n-max 3 \
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 \
  --log-file "$ROOT/logs/server.log"
