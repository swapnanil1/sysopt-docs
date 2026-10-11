@echo off
:: Double-click launcher for llama-server. Lives in C:\llm next to bin\, models\, logs\ and rocm\.
:: One copy per model: duplicate, rename, change the -m line and the per-model flags (02-launch-and-tuning.md).
:: CHANGE: the model file name, -c, -ctk/-ctv, --no-reasoning-preserve, --spec-type. Everything else is machine-wide.
:: The -mtp file carries the model's own draft head; --spec-type draft-mtp uses it. A file without the
:: head needs --spec-type ngram-mod instead, and then -c 65536 fits (02-launch-and-tuning.md, section 4.4).
:: The sampling line is the model card's setting; a client that sends its own values overrides it.
:: --cache-ram 0: the server's prompt cache saves a slot's state to RAM before each new task; on this hybrid
:: model that save throws and kills the server on the second request. Off = no crash; slot reuse by prefix
:: still works. --cache-reuse needs the cache, so it is not available with this model.
:: -c 32768 at q8_0 with the draft head measured 14.9 GB of VRAM; 49152 needs q4_0 or a larger pagefile (01-build.md 6).
title llama-server  Swift-1.5-Qwen3.8-27B
setlocal
set "ROOT=%~dp0"
set "PATH=%ROOT%bin;%ROOT%rocm\bin;%PATH%"
:: Qwen3.5/3.8 files carry 96 small BF16 tensors (ssm_alpha/ssm_beta). Those go through rocBLAS, which by
:: default forwards them to hipBLASLt, and hipBLASLt crashes on gfx1201 in this SDK (access violation in
:: libhipblaslt.dll on the first draft step). 0 = rocBLAS uses its own kernels. Measured: no speed change.
set "ROCBLAS_USE_HIPBLASLT=0"

netstat -ano | findstr /r /c:":8080 .*LISTENING" >nul
if not errorlevel 1 (
    echo Something is already listening on port 8080:
    netstat -ano | findstr /r /c:":8080 .*LISTENING"
    echo If it is llama-server, run close-llm.cmd first. The last number is the process id.
    pause
    exit /b 1
)

cd /d "%ROOT%bin"
llama-server.exe ^
  -m "%ROOT%models\Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" ^
  -ngl 99 -c 32768 -np 1 -n 16384 -b 1024 -ub 512 -t 6 ^
  -fa on -ctk q8_0 -ctv q8_0 -lm none --jinja ^
  --no-reasoning-preserve --no-context-shift --timeout 600 --threads-http 2 --port 8080 ^
  --cache-ram 0 ^
  --spec-type draft-mtp --spec-draft-n-max 3 ^
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 ^
  --log-file "%ROOT%logs\server.log"

echo.
echo llama-server exited with code %ERRORLEVEL%
pause
