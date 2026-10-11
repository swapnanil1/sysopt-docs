# PowerShell equivalent of start-llm.cmd, for running from a terminal you already have open.
# CHANGE $Model and the per-model flags (-c, -ctk/-ctv, --no-reasoning-preserve, --spec-type); see 02-launch-and-tuning.md.
# The -mtp file carries the model's own draft head; --spec-type draft-mtp uses it. A file without the
# head needs --spec-type ngram-mod instead, and then -c 65536 fits.
# The sampling line is the model card's setting; a client that sends its own values overrides it.
$Root  = "C:\llm"
$Model = "$Root\models\Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf"

$env:PATH = "$Root\bin;$Root\rocm\bin;$env:PATH"
$env:ROCBLAS_USE_HIPBLASLT = "0"     # hipBLASLt crashes on gfx1201 in this SDK; see start-llm.cmd
Set-Location "$Root\bin"
.\llama-server.exe `
  -m $Model `
  -ngl 99 -c 32768 -np 1 -n 16384 -b 1024 -ub 512 -t 6 `
  -fa on -ctk q8_0 -ctv q8_0 -lm none --jinja `
  --no-reasoning-preserve --no-context-shift --timeout 600 --threads-http 2 --port 8080 `
  --cache-ram 0 `
  --spec-type draft-mtp --spec-draft-n-max 3 `
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 `
  --log-file "$Root\logs\server.log"
