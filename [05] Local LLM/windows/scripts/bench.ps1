# llama-bench with the same flags the server uses. Prints only the result table.
#   C:\llm\scripts\bench.ps1 -Model C:\llm\models\model.gguf
#   add -Prompt "512,2048" -Depth "0,16384" -UBatch "512,1024" for the tuning run in 02-launch-and-tuning.md section 5
param(
    [Parameter(Mandatory = $true)][string]$Model,
    [string]$Root = "C:\llm",          # CHANGE only if you use another root
    [string]$Prompt = "512",
    [int]$Gen = 64,
    [string]$Depth = "0",
    [string]$UBatch = "512",
    [string]$KV = "q8_0"
)
$env:PATH = "$Root\bin;$Root\rocm\bin;$env:PATH"
$exe = Join-Path $Root "bin\llama-bench.exe"
Write-Output "=== $exe ==="
& $exe -m $Model -ngl 99 -fa on -ctk $KV -ctv $KV -lm none -b 2048 -ub $UBatch -t 6 `
    -p $Prompt -n $Gen -d $Depth -r 1 -o md 2>&1 |
    Where-Object { "$_" -match '^\|' -or "$_" -match 'Device 0|error|build:' }
