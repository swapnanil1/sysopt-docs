# Step 3: LAN launcher, speed checks, and Sway

[Linux overview](../%5B02%5D%20Linux.md) · [Source build](02-build-rocm.md) · [Code client](../common/04-code-oss-setup.md)

The Linux baseline is **65,536 total context tokens** (`-c 65536`), **16,384 maximum generated tokens** (`-n 16384`), one inference slot, q8 KV cache, and MTP drafting. The model listens on **all IPv4 interfaces**, port **18080**. Use the server's actual LAN IP in clients; `0.0.0.0` is a bind address. Loopback URLs below are server-side diagnostics, not a localhost-only hosting mode.

## 1. Install and inspect the launcher

```bash
LLM_DOCS="/path/to/sysopt-docs/[05] Local LLM"
mkdir -p "$HOME/llm"/{models,logs,scripts}
cp "$LLM_DOCS/linux/scripts/start-llm.sh" "$LLM_DOCS/linux/scripts/close-llm.sh" "$HOME/llm/"
cp "$LLM_DOCS/linux/scripts/bench.sh" "$HOME/llm/scripts/"
chmod +x "$HOME/llm/start-llm.sh" "$HOME/llm/close-llm.sh" "$HOME/llm/scripts/bench.sh"
```

These commands install the repository defaults. If you already customized installed scripts, review their differences before replacing them. Adjust `LLM_DOCS` if the repository is elsewhere. The launcher prefers a source-built executable at `~/llm/src/build/bin/llama-server`, otherwise the package in `/usr/bin`. It prints the selected path and checks that the model exists before starting. `BIN=/usr/bin ~/llm/start-llm.sh` selects the package explicitly.

The effective command for the source build is:

```bash
ROCBLAS_USE_HIPBLASLT=0 "$HOME/llm/src/build/bin/llama-server" \
  --host 0.0.0.0 --port 18080 \
  -m "$HOME/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" \
  --alias swift-qwen --device ROCm0 \
  -ngl 99 -c 65536 -np 1 -n 16384 -b 2048 -ub 512 -t 6 -tb 12 \
  -fa on -ctk q8_0 -ctv q8_0 --jinja \
  --no-reasoning-preserve --no-context-shift \
  --timeout 600 --threads-http 2 --cache-ram 0 \
  --spec-type draft-mtp --spec-draft-n-max 3 \
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 \
  --presence-penalty 0 --repeat-penalty 1.0 \
  --log-file "$HOME/llm/logs/server.log"
```

Run either the launcher or the raw command, not both. For normal use:

```bash
~/llm/start-llm.sh
```

The shipped launcher has no `--local` mode. Check [LAN addresses and firewall access](../common/05-network-access.md), then open `http://SERVER-IP:18080` from a client. The trusted-LAN service has no API authentication; do not forward it through the router.

### What these settings mean

- `-c 65536` is the combined input/output capacity, not 65,536 input plus a reply. Configure Code for **49,152 input + 16,384 output**, or use `contextWindow: 65536` and `maxOutputTokens: 16384`.
- `-n 16384` is a reply ceiling, not a second allocation of 16,384 context tokens. Clients can request fewer tokens; reasoning may consume part of a response budget.
- `-np 1` shares one inference slot between clients. New requests may wait; a second editor does not load another model copy.
- `-ngl 99` requests GPU offload for all layers of this model; verify actual loading rather than treating the flag as proof.
- `-b 2048 -ub 512 -t 6 -tb 12` are the example logical batch, physical micro-batch, generation-thread, and prompt-processing-thread settings. Measure them on the target hardware rather than treating them as a universal optimum.
- `-fa on -ctk q8_0 -ctv q8_0` enables flash attention and quantized KV cache. Keep these constant when comparing benchmark runs.
- The `-mtp` GGUF contains a draft head used by `draft-mtp`; a file without that head needs a different speculation configuration. MTP acceptance and speed depend on the task.
- `--cache-ram 0` retains the workaround for state-save crashes observed in the Windows setup. It is not evidence that every Linux version has the same crash.
- `ROCBLAS_USE_HIPBLASLT=0` retains the rocBLAS workaround from Windows. Linux necessity was not isolated in an A/B test. Benchmarking without this variable is a different configuration.
- `--no-context-shift` disables context shifting. It does **not** prevent GPU-to-system-memory fallback, guarantee an early OOM, or enforce GPU residency. `--no-reasoning-preserve` requests that earlier reasoning not be retained by the supported template.

## 2. Measure throughput without mixing workloads

Record your GPU target, driver/runtime versions, llama.cpp commit, model filename, KV types, batch settings, context depth, and whether MTP is enabled alongside each result. Store machine-specific measurements privately if you do not want to publish your hardware or environment.

| Measurement                         | What it tells you                                 | Limitation                                            |
| ----------------------------------- | ------------------------------------------------- | ----------------------------------------------------- |
| `llama-bench pp2048`, 3 repetitions | Synthetic processing speed for 2,048 input tokens | Does not measure server MTP or a filled 64K context   |
| `llama-bench tg128`, 3 repetitions  | Synthetic generation speed without server MTP     | Not directly comparable to a different server request |
| Server `predicted_per_second`       | Generation rate for the actual request            | Depends on workload, context depth, and drafting      |
| Server `prompt_per_second`          | Prompt processing rate for the actual request     | Very short prompts can be dominated by overhead       |
| `draft_n_accepted / draft_n`        | MTP draft acceptance for that request             | Varies by content and generation settings             |
| Startup duration                    | Time to load and initialize the model             | Not prompt processing or generation speed             |

Use comparable prompts, token counts, context depth, and environment settings for controlled comparisons. In particular, the launcher sets `ROCBLAS_USE_HIPBLASLT=0`; the standalone benchmark does not set it unless you supply it. Do not infer an MTP speedup percentage from unrelated synthetic and server workloads.

The maintained baseline remains **65,536 / 16,384**. Startup and one short completion do not establish speed or stability after filling the context. Recheck memory and performance with representative long requests before depending on the full budget.

## 3. Reproduce a baseline before tuning

Stop the model server first; the benchmark needs its VRAM. It loads the weights, runs synthetic prefill and generation tests, repeats each three times, and exits. It does not edit the model or start a persistent service.

```bash
~/llm/close-llm.sh
~/llm/scripts/bench.sh "$HOME/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" ROCm0
```

For micro-batch and depth comparisons:

```bash
~/llm/scripts/bench.sh "$HOME/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" ROCm0 512,2048 0,16384 512,1024
```

Arguments are model, device, prompt lengths, context depths, micro-batches, and optional KV type. Only test `Vulkan0` if `--list-devices` shows it. The wrapper uses `-b 2048 -t 6 -n 128`, not the old `tg32`/`tg64` examples, and preserves diagnostics instead of hiding failures behind a result filter. This version of `llama-bench` has no separate `-tb` option; benchmark `-t 6` and `-t 12` separately if needed, and use real server requests to assess its split `-t 6 -tb 12` configuration.

### Measure the actual server with MTP

Restart the launcher and wait for `listening`. In another terminal on the server:

```bash
curl -fsS http://127.0.0.1:18080/completion \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Write a detailed Python implementation of an LRU cache with type hints, documentation, and usage examples.","n_predict":512,"temperature":0,"cache_prompt":false,"stream":false}' \
  -o "$HOME/llm/logs/speed-test.json"
python -c 'import json,pathlib; d=json.loads((pathlib.Path.home()/"llm/logs/speed-test.json").read_text()); print(json.dumps(d.get("timings",d),indent=2))'
```

From another client replace loopback with the server IP. Read `prompt_per_second`, `predicted_per_second`, `draft_n`, and `draft_n_accepted`. Repeat representative short and long coding requests before choosing different settings. Compare like-for-like workloads, not synthetic decode directly with a different MTP prompt.

### Monitor memory under real load

```bash
awk '{printf "%s: %.0f MiB\n", FILENAME, $1/1048576}' /sys/class/drm/card*/device/mem_info_vram_used
awk '{printf "%s: %.0f MiB\n", FILENAME, $1/1048576}' /sys/class/drm/card*/device/mem_info_gtt_used
```

Observe after startup and after a long representative request. Leave desktop headroom. GTT usage alone is not proof that model weights spilled; correlate it with buffer logs, VRAM pressure and throughput. There is no universal 15,300 MiB threshold for all desktops/backends. If allocation fails, inspect the logs and reduce memory pressure before retrying. The 64K baseline is not a promise that every 16 GB desktop can run it under every workload.

## 4. Sway and the optional service

For a visible terminal, add to Sway's config:

```text
bindsym $mod+F9 exec foot --title llama-server sh -lc '~/llm/start-llm.sh'
bindsym $mod+F10 exec sh -lc '~/llm/close-llm.sh'
```

Use your terminal's equivalent if it is not `foot`. The launcher runs in the foreground; Ctrl+C stops it.

For a background service instead:

```bash
LLM_DOCS="/path/to/sysopt-docs/[05] Local LLM"
mkdir -p "$HOME/.config/systemd/user"
cp "$LLM_DOCS/linux/scripts/llm.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user start llm
journalctl --user -u llm -f
```

Use `systemctl --user stop llm` for a service-managed instance. Do not start a second terminal instance beside it. Enable the unit only if you want automatic model loading at login.

`close-llm.sh` sends SIGINT to all same-user processes named `llama-server`, waits, then force-stops survivors. It does not target one model or port-specific process. Use Ctrl+C for an individual foreground instance.
