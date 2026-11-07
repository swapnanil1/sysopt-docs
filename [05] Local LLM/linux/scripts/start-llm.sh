#!/usr/bin/env bash
# Launcher for llama-server. Lives in ~/llm next to models/, logs/ and scripts/.
# One copy per model: duplicate, rename, change MODEL= and the per-model flags (03-launch-and-tuning.md).
# CHANGE: MODEL, DEVICE, and the per-model flags (-c, -ctk/-ctv, --no-reasoning-preserve, --spec-type). The rest is machine-wide.
# The -mtp file carries the model's own draft head; --spec-type draft-mtp uses it. A file without the
# head needs --spec-type ngram-mod instead.
# -c 65536 with the head and q8_0 KV measured on Vulkan0 (16 GB AMD GPU example): 15 143 MiB after load,
# 15 303 MiB idle after a 28.8k-token prompt, 737 tok/s prompt processing at that depth, 59 tok/s decode. That is
# an example near the VRAM limit, not a guaranteed capacity: close GPU-heavy apps or reduce -c.
# The sampling line is the model card's setting; a client that sends its own values overrides it.
set -euo pipefail

# Serve the model on the LAN. Clients use the server's actual IPv4 address.
LISTEN_HOST=0.0.0.0
case "$#:${1:-}" in
    0:) ;;
    1:-h|1:--help)
        echo "Usage: $0"
        echo "Listens on all IPv4 interfaces, port 18080, no API key."
        exit 0 ;;
    *) echo "Usage: $0 (no arguments; LAN binding is configured in the script)" >&2; exit 2 ;;
esac

ROOT="$HOME/llm"
if [[ -x "$ROOT/src/build/bin/llama-server" ]]; then
    DEFAULT_BIN="$ROOT/src/build/bin"
else
    DEFAULT_BIN=/usr/bin
fi
BIN=${BIN:-$DEFAULT_BIN}                        # BIN=/usr/bin ./start-llm.sh forces the package
MODEL="$ROOT/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"
DEVICE=ROCm0                                   # ROCm0 or Vulkan0; see: "$BIN/llama-server" --list-devices
PORT=18080

if [[ ! -x "$BIN/llama-server" || ! -f "$MODEL" ]]; then
    echo "Missing executable ($BIN/llama-server) or model ($MODEL). Check the build and MODEL path." >&2
    exit 1
fi
echo "Binary: $BIN/llama-server"
if ss -ltn "sport = :$PORT" | grep -q LISTEN; then
    echo "Something is already listening on port $PORT:"
    ss -ltnp "sport = :$PORT"
    echo "If it is llama-server, run close-llm.sh first."
    exit 1
fi

mkdir -p "$ROOT/logs"
echo "LAN access: http://<PC-LAN-IP>:$PORT (no API key; trusted networks only)"
# Qwen3.5/3.8 files carry 96 small BF16 tensors that go through rocBLAS. On the Windows SDK rocBLAS forwards
# them to hipBLASLt, which crashes on gfx1201; 0 makes rocBLAS use its own kernels. Not confirmed needed on
# Linux ROCm 7.2, harmless if not. Ignored by the Vulkan backend.
export ROCBLAS_USE_HIPBLASLT=0
exec "$BIN/llama-server" \
  --host "$LISTEN_HOST" \
  -m "$MODEL" \
  --alias swift-qwen \
  --device "$DEVICE" \
  -ngl 99 -c 65536 -np 1 -n 16384 -b 2048 -ub 512 -t 6 -tb 12 \
  -fa on -ctk q8_0 -ctv q8_0 --jinja \
  --no-reasoning-preserve --no-context-shift \
  --timeout 600 --threads-http 2 --port "$PORT" \
  --cache-ram 0 \
  --spec-type draft-mtp --spec-draft-n-max 3 \
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 \
  --log-file "$ROOT/logs/server.log"
