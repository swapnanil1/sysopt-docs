# Step 2: Launch flags, what carries over, and how to tune a new model in five minutes

## What this step is

The launcher from [`scripts/start-llm.cmd`](./scripts/start-llm.cmd) explained flag by flag, split into flags that are properties of the machine and flags that must be re-derived per model, with the measurements behind each choice, a short procedure for new models, and how to start and stop the server day to day. [`scripts/start-server.ps1`](./scripts/start-server.ps1) is the same launch for a PowerShell window.

Hardware facts that drive every decision below:

| Fact | Reference value | Consequence |
|---|---|---|
| VRAM | 16 304 MB | model + KV cache + ~1 GB compute buffers must stay under ~15 GB |
| VRAM bandwidth | ~640 GB/s | decode is bandwidth bound: roughly 350 GB/s effective ÷ model size in GB |
| Host RAM | 16 GB | one model at a time; never build while serving |
| Driver model | WDDM | if VRAM overflows, Windows pages to system RAM over PCIe without an error, and speed drops 5 to 10× |

---

## 1. Starting and stopping

The launcher lives in `C:\llm` beside `bin\`, `models\`, `logs\` and `rocm\` (layout in the index). It is deliberately a plain batch file in a plain console window: no service, no watchdog, no restart logic.

```bat
title llama-server  Qwen3.8-27B
set "ROOT=%~dp0"
set "PATH=%ROOT%bin;%ROOT%rocm\bin;%PATH%"           :: HIP DLLs next to the exe win over System32; rocblas from rocm\

netstat -ano | findstr /r ":8080 .*LISTENING" >nul   :: refuse a second copy instead of failing with "address in use"
if not errorlevel 1 ( echo already running & pause & exit /b 1 )

cd /d "%ROOT%bin"
llama-server.exe ... --log-file "%ROOT%logs\server.log"
echo llama-server exited with code %ERRORLEVEL%
pause                                                  :: keeps the window open after a crash so the error is readable
```

**Desktop shortcut.** Right-click the desktop, New, Shortcut, target:

```
%SystemRoot%\System32\cmd.exe /c "C:\llm\start-llm.cmd"
```

Set *Start in* to `C:\llm` in the shortcut's properties. Wrapping the `.cmd` in `cmd /c` is what makes the shortcut pinnable to the taskbar and Start.

**One gap in the port check.** The server binds port 8080 only after the model has loaded, about 15 seconds after the window opens. A second double-click inside that window is not refused; it starts a second load, and the second one fails with "address in use" once the first finishes. Outside that window the check works as intended. If a launcher ever reports "already listening" with no server answering, a previous launch is still loading: wait for it.

**Stopping.** Close the window, press Ctrl+C in it, or double-click `close-llm.cmd`, which works whether the server runs in a window, hidden, or from a terminal. It asks the process to exit and force-kills it only if it is still there two seconds later. llama-server keeps no state on disk, so there is nothing to lose: the close signal shuts it down in under a second, and even a hard kill is harmless because the driver frees the VRAM and the host commit the moment the process ends. The next double-click starts clean.

**A second model.** Copy `start-llm.cmd` to `start-<name>.cmd`, change the `-m` line and the per-model flags in section 4, make a second shortcut. The port check means two cannot run at once, which is right on 16 GB.

**Environment variables.** One, set inside the launcher for its own window: `ROCBLAS_USE_HIPBLASLT=0`. Qwen3.5 and 3.8 files carry 96 small BF16 tensors (the `ssm_alpha` and `ssm_beta` weights of the Gated DeltaNet layers) that llama.cpp's own kernels cannot handle, so they go through rocBLAS. In this SDK rocBLAS forwards them to hipBLASLt, which has a gfx1201 bug: an access violation inside `libhipblaslt.dll` the first time the draft head runs. With the variable at 0 rocBLAS uses its own kernels, at no measurable cost. The launcher sets PATH for its own window only; `HIP_PATH` is for building (step 1) and is not read at runtime.

---

## 2. The launch flags, annotated

```powershell
.\llama-server.exe `
  -m $Model `
  -ngl 99          # all layers on the GPU                                   MACHINE
  -c 49152         # context window; 65536 with a file that has no draft head  MODEL (VRAM)
  -np 1            # one slot; each slot owns a full KV cache                MACHINE (single user)
  -n 16384         # max tokens per reply. A counter, not memory: with xhigh    MACHINE
                   # thinking a reply can pass 8k and was cut off mid-thought
  -b 1024 -ub 512  # batch / micro-batch for prompt processing                MACHINE (measured)
  -t 6             # CPU threads; irrelevant with -ngl 99                     MACHINE
  -fa on           # flash attention                                          MACHINE
  -ctk q8_0 -ctv q8_0   # KV cache precision                                  MODEL (VRAM), section 4.1
  -lm none         # no memory-mapping: stream weights straight to VRAM       MACHINE (16 GB RAM)
  --jinja          # use the model's embedded chat template (tool calls)      MODEL, almost always on
  --no-reasoning-preserve   # drop earlier <think> blocks from history        MODEL (thinking models)
  --no-context-shift        # fail loudly instead of silently evicting        MACHINE (stability)
  --timeout 600 --threads-http 2 --port 8080                                  MACHINE
  --cache-ram 0    # prompt cache off: its state save crashes this model       MODEL (stability), section 7
  --spec-type draft-mtp --spec-draft-n-max 3   # the model's own draft head   MODEL, section 4.4
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0
                            # the model card's sampling, as server defaults   MODEL, section 4.5
```

### The measurements behind it

Reference model: a 27B hybrid-attention model at IQ3_S, 11 GB without the draft head and 12 GB with it. All runs with flash attention on, all layers on the GPU, no memory-mapping.

| Test | Result | Decision |
|---|---|---|
| `-ub 512` vs `-ub 1024`, context depth 0 | 1072 vs 1057 tok/s prefill | tie |
| `-ub 512` vs `-ub 1024`, depth 16 384 | **905 vs 266** tok/s prefill; 29.9 vs 26.0 tok/s decode | 512 |
| KV cache q4_0 vs q8_0, depth 0 and 16k | identical within 0.2 tok/s | q8_0 (no cost) |
| `--spec-type ngram-mod`, verbatim code repeat, plain file | 32 → **176** tok/s decode, identical output | on for files without a draft head |
| `--spec-type ngram-mod`, fresh code, plain file | 32.1 tok/s, unchanged | no penalty |
| VRAM, plain file, q8_0 KV, 65k context, after one request | 14 955 MB dedicated, 660 MB shared | fits |
| `--spec-type draft-mtp`, fresh code, mtp file, 49k | 32 → **48 to 50** tok/s, 76 % of drafts accepted | on |
| `--spec-draft-n-max` 2 vs 3 vs 4, 49k | 48, 49, 51 tok/s; 15 573, 15 731, 15 873 MB dedicated | 2: the rest is noise for 300 MB |
| draft-mtp with a 28 402-token prompt in context | 809 tok/s prefill, 40 tok/s decode, 80 % accepted | holds up |
| VRAM, mtp file, 49k vs 65k, after one request | 15 573 / 870 MB vs 16 068 / **1 081** MB shared | 49k; 65k spills |

---

## 3. Flags that are the same for every model on the example configuration

`-ngl 99 -np 1 -n 16384 -b 1024 -ub 512 -t 6 -fa on -lm none --no-context-shift --timeout 600 --threads-http 2 --cache-ram 0`

One deserves a sentence:

- **`-ub 512`.** At deep context the attention kernel's working set per micro-batch grows with depth, and 1024-token micro-batches overflow the GPU's fast on-chip memory on RDNA 4. Re-check only for models with unusual head sizes (section 5).

---

## 4. Flags that must be re-derived per model

### 4.1 Context `-c` and KV cache type `-ctk` / `-ctv`

They share one VRAM budget, so decide them together.

1. Start the server once with the context you want and read the three buffer lines it prints:

   ```
   CUDA0 model buffer size   = ... MiB
   CUDA0 KV buffer size      = ... MiB
   CUDA0 compute buffer size = ... MiB
   ```

2. Add them. Above about 15 600 MiB, or if Task Manager → GPU → *Shared GPU memory* sits above ~0.9 GB while idle, the model is spilling to system RAM. With the draft head the benchmark configuration idles at 15 573 MB dedicated and 870 MB shared; at 65k the shared figure jumped to 1 081 MB, and that jump is the sign. Halve `-c`, or drop the KV cache from q8_0 to q4_0, in that order of preference.
3. Send one long prompt and confirm prefill is still in the hundreds of tokens per second.

Rules of thumb:

| Model class | KV cost per token | 65k context on 16 GB |
|---|---|---|
| Hybrid attention (Qwen3.5, GLM Flash, Gemma 4 with sliding window) | low | yes, even at q8_0 |
| Dense GQA with 8 KV heads (Llama 3, Mistral, dense Qwen3) | medium | q8_0 at 32k, q4_0 at 65k, with a model of 12 GB or less |
| Dense multi-head or 32+ KV heads | high | no; plan on 16k to 32k |

Quality: q8_0 KV is indistinguishable from f16. q4_0 KV is fine for prose and short tasks and is the first suspect when a coding agent starts producing malformed tool calls deep into a session. Prefer q8_0 with a smaller context over q4_0 with a larger one for agent work.

### 4.2 `--jinja` and `--no-reasoning-preserve`

- `--jinja` is required for tool calling. Keep it for every chat model. If a model's embedded template is broken (rare, usually old GGUF conversions) the server says so at startup; then pass `--chat-template` with a built-in template name.
- `--no-reasoning-preserve` matters only for thinking models (Qwen3.x, DeepSeek-R1 class, GLM). It strips earlier `<think>` blocks from the history so they don't consume context. Harmless elsewhere.

### 4.3 The weight quantization (the largest speed knob after the build)

Decode is bandwidth bound. On the reference GPU, tok/s ≈ 350 ÷ model file size in GB.

| File size | Expected decode |
|---|---|
| 11 GB (27B at IQ3_S / Q3_K) | ~32 tok/s |
| 9 GB (14B at Q4_K_M, or 24B at IQ3_XS) | ~40 tok/s |
| 5 GB (8B at Q4_K_M) | ~70 tok/s |
| 2 GB (3B to 4B at Q4) | ~150 tok/s |

Below about 3.5 bits per weight quality falls quickly. IQ3_S (3.44 bpw) is the floor for a 27B that is still worth running; Q4_K_M (4.8 bpw) is the comfortable choice when the model is 20B or smaller.

### 4.4 Speculation `--spec-type`

Speculative decoding lets a small helper guess the next tokens and the model confirm them in one pass; the output is unchanged. The server takes one speculation type per launch, and the right one depends on the file:

| The file has | Flag | Costs | What it speeds up |
|---|---|---|---|
| the model's own draft head (a block numbered one past the last layer, `-mtp` in the GSQ-RCO file names) | `--spec-type draft-mtp --spec-draft-n-max 2` | about 0.8 GB in use (measured); `-c 49152` on 16 GB | fresh text: 32 → 49 tok/s measured here, 40 at 28k depth |
| no draft head | `--spec-type ngram-mod` | nothing | repeats and edits only: 32 → 176 tok/s measured here, fresh text unchanged |

Section 3.2 of [common/02](../common/02-model-choice-and-speculation.md) shows how to tell which kind of file you have. `draft-mtp` on a file without the head fails at startup; `ngram-mod` on a file with it works and wastes the head.

On another card the head is measured in ten minutes, laid out in common/02 section 6: one prompt asking for new code, read `draft_n_accepted` and the decode tok/s in the timings, watch shared GPU memory, then sweep `--spec-draft-n-max` 2 to 4 and try `-c 65536`.

### 4.5 Sampling defaults and reasoning effort

The last launcher line sets the sampling the model card evaluated with: temperature 1.0, top-p 0.95, top-k 20, min-p off, both repetition penalties off. They are server defaults, so a client that sends its own temperature wins. Qwen's thinking models are tuned for temperature 1.0 and repeat themselves inside long thinking when it is lowered; the repetition penalties are off because they punish writing the same identifier twice, which is most of what code is.

Reasoning effort is a switch in the chat template, not a flag: xhigh, medium or low, xhigh when a request sets nothing. The Swift 1.5 model in the launcher was trained and scored at xhigh and loses two points at medium, so the launcher sets nothing. To make every request brief, for a server that only answers short questions:

```
--chat-template-kwargs "{\"reasoning_effort\":\"low\"}"
```

`--reasoning-budget N` is a hard cut after N thinking tokens. Leave it at the default, unlimited. Background in common/02 section 3.3.

---

## 5. The five-minute check for any new model

```powershell
# 1. Does it fit, and how fast is it at depth 0 and at 16k?
C:\llm\scripts\bench.ps1 -Model C:\llm\models\NEW-MODEL.gguf -Prompt 2048 -Gen 32 -UBatch "512,1024" -Depth "0,16384"
# which runs:
C:\llm\bin\llama-bench.exe `
  -m C:\llm\models\NEW-MODEL.gguf -ngl 99 -fa on -lm none -t 6 `
  -ctk q8_0 -ctv q8_0 -b 2048 -ub 512,1024 -p 2048 -n 32 -d 0,16384 -r 1
```

Read the table:

- `pp2048` at depth 0: hundreds of tok/s or more. Below 50 means a broken build, not a slow model (step 1, 7.1).
- `pp2048 @ d16384`: take the `-ub` with the higher number. On this GPU it has been 512 every time.
- `tg32 @ d16384`: the decode speed an agent actually sees after a few turns.
- An allocation error at `d16384` means the KV cache doesn't fit. Repeat with `-ctk q4_0 -ctv q4_0`, then with a smaller `-d`.

Then: start the server, check Task Manager (dedicated ≤ ~15.6 GB, shared ≤ ~0.9 GB while idle), and send one long prompt from the editor to read the reported prompt tok/s.

**Check:** the launch script's `-c`, `-ctk`/`-ctv` and `-ub` match what the run showed, and idle shared GPU memory is under 0.9 GB.

---

## 6. A prompt that writes the flags for you

Paste the block into a capable model, replace the last line, and it returns a launch command with the VRAM arithmetic shown. Edit the MACHINE lines for other hardware.

```
You are configuring llama.cpp's llama-server on this exact machine. Produce a launch command and
explain each per-model choice. Do not invent benchmark numbers; reason from sizes.

MACHINE
- GPU: AMD Radeon RX 9070, 16 304 MB VRAM, ~640 GB/s, RDNA 4 (gfx1201), ROCm 10.1 on Windows 11 (WDDM).
- Host RAM: 16 GB. Memory-mapping weights is not allowed (use -lm none).
- CPU: 6 cores. All layers must go on the GPU (-ngl 99).
- llama.cpp: current master, ROCm backend. Flash attention works for all head sizes.
- Usage: single user, coding agents over the OpenAI-compatible API, long multi-turn sessions.

FIXED FLAGS FOR THIS MACHINE (always include verbatim)
-ngl 99 -np 1 -n 16384 -b 1024 -ub 512 -t 6 -fa on -lm none --no-context-shift --cache-ram 0
--timeout 600 --threads-http 2 --port 8080

MEASURED FACTS TO RESPECT
- -ub 512 beats -ub 1024 at deep context on this GPU; do not change it.
- KV cache q8_0 costs no speed versus q4_0; prefer q8_0, use q4_0 only to make a context fit.
- Total GPU allocation must stay under ~15 600 MiB: model file size + KV cache + ~1 000 MiB compute buffer,
  plus ~800 MiB when the file has a multi-token-prediction head and it is used.
- Decode speed is bandwidth bound: roughly 350 GB/s effective ÷ model file size in GB.
- Below ~3.4 bits per weight quality drops sharply; prefer a smaller model at Q4_K_M over a larger one at IQ2.

DECIDE PER MODEL
1. Which GGUF quant to download so the file is <= ~12 GB (name the exact quant). If the maker offers the
   same quant with the model's multi-token-prediction head, take that one and say so.
2. -c: compute KV bytes per token for this architecture (layers × kv_heads × head_dim × 2 × bytes;
   count only full-attention layers for hybrid or sliding-window models) and choose the largest -c in
   {16384, 32768, 49152, 65536} that fits with q8_0 KV. If 16384 does not fit at q8_0, use q4_0 and say so.
3. -ctk/-ctv: q8_0 unless step 2 forced q4_0.
4. --jinja for any instruct/chat model. --no-reasoning-preserve only if the model is a thinking model.
5. --spec-type draft-mtp --spec-draft-n-max 2 if the file has the head, otherwise --spec-type ngram-mod.
6. The sampling defaults from the model card (--temp, --top-p, --top-k, --min-p, penalties).
7. Any architecture-specific flag (--swa-full, --chat-template, --override-kv).

OUTPUT
- One PowerShell command with backtick line continuations.
- A four-line table: model file size, KV MiB at the chosen -c, expected decode tok/s, expected prefill tok/s range.
- One line on what to watch in Task Manager to confirm nothing spilled to shared memory.

MODEL: <exact Hugging Face repo or GGUF file name>
```

---

## 7. Not in the script, and why

| Flag | Status | Reason |
|---|---|---|
| `--cache-ram 0` | **in the script** | The server's prompt cache saves an idle slot's full state to RAM before every new task. On this hybrid model that save throws a C++ exception and the process dies on the second request, reproducibly, with or without the draft head; it was also the cause of the earlier "context shift" crash (`f_keep = 0.349`). With the cache off, slot reuse by longest common prefix still works, so an agent's unchanged prefix is still not re-processed. |
| `--cache-reuse 256` | not available | It needs the prompt cache, which must be off on this model. Revisit on a newer llama.cpp if the state save is fixed; it would be the largest win for agent loops. |
| `-md` draft model | no | The model's own head does the same job from inside the main file. A separate draft costs about 2.7 GB and is only worth a look if the head's acceptance rate turns out poor (common/02, section 6). |
| `--spec-type ngram-mod` | for files without a draft head | Free and measured at 176 tok/s on repeats, but it cannot be combined with `draft-mtp`, and the head also covers fresh text. |
| `--reasoning-budget` | no | A hard cut mid-thought. The model in the launcher was trained to think less on its own; section 4.5. |
| `--chat-template-kwargs` | per use | Sets the reasoning effort server-wide. Only for a server that should answer briefly; section 4.5. |
| `-np 2` | no | Each slot owns a full KV cache. Two at 65k do not fit. |
| `--mlock` | no | Pointless with `-lm none`; weights are not in host memory. |
| `-ot` / `--override-tensor` | no | For parking MoE experts in RAM when a model doesn't fit VRAM. 16 GB of RAM leaves no room for that. |
| `ROCBLAS_USE_HIPBLASLT`, `HSA_OVERRIDE_GFX_VERSION` | removed | No effect on RDNA 4 / Windows (step 1, 7.3). |
