# Step 3: The launcher, Sway integration, and what carries over from the Windows measurements

## What this step is

The launch flags, split into what is a property of the card (and therefore identical to the Windows guide, which measured them) and what is Linux-specific or must be re-measured. Then the launcher script, how to start it from Sway, how to stop it, and the optional systemd user unit.

The flag measurements in the Windows guide use the example GPU target with llama.cpp's own kernels. The ROCm backend on Linux runs the same kernels, so micro-batch size, KV cache precision and the speculation flags carry over as they are. What does not carry over: anything that depends on the OS memory manager (there is no host commit on Linux), the Vulkan backend (different kernels; re-measure), and absolute numbers (re-measure, expected to be within a few percent on ROCm).

---

## 1. The launcher, annotated

`~/llm/start-llm.sh`:

```bash
BIN=/usr/bin                       # or $HOME/llm/src/build/bin after step 2
MODEL=$HOME/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf     # CHANGE
DEVICE=ROCm0                       # ROCm0 or Vulkan0; `llama-server --list-devices` shows what exists

"$BIN/llama-server" \
  -m "$MODEL" \
  --alias swift-qwen \                                     # stable model id for Zed and other API clients
  --device "$DEVICE" \
  -ngl 99 -c 65536 -np 1 -n 16384 -b 1024 -ub 512 -t 6 \     # CARD, measured on Windows, carries over; -c is MODEL (VRAM), measured below; -n is a reply cap, not memory
  -fa on -ctk q8_0 -ctv q8_0 --jinja \                         # q8_0 costs nothing (measured); MODEL (VRAM)
  --no-reasoning-preserve --no-context-shift \                 # MODEL (thinking) / stability
  --timeout 600 --threads-http 2 --host 0.0.0.0 --port 18080 \
  --cache-ram 0 \                                              # prompt cache off: its state save crashes this model (Windows step 2, section 7)
  --spec-type draft-mtp --spec-draft-n-max 3 \                 # the file's own draft head; ngram-mod for a file without one
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 \   # the model card's sampling
  --log-file "$HOME/llm/logs/server.log"
```

The speculation line and the context size go together: the `-mtp` file carries the model's draft head and `draft-mtp` uses it, at about 0.8 GB of VRAM. Measured on Windows with the same kernels: 48 to 62 tok/s on fresh code, 40 tok/s with 28k tokens in context, 49k at q8_0 on the edge of the card and 32k once rocBLAS's own kernels were in use. A file without the head takes `--spec-type ngram-mod`.

**Do not inherit the Windows context ceiling.** On Windows the card also carries WDDM's own reservation and a larger runtime overhead; on Linux the same 16 GB holds more. The quality of a local model on a 16 GB card is bought with that headroom: a longer context so an agent forgets less of the repository, and a q8_0 cache that never has to drop to q4_0, which is where tool-call JSON starts to break at depth. The model's accuracy on a given prompt is the same on both systems; what differs is how much of the conversation it can still see.

Example measurements on a 16 GB AMD GPU using Vulkan0 with desktop GPU memory in use, the Swift mtp file at q8_0 with the draft head:

| Context | After load | Idle after a 28.8k-token prompt | Prompt processing at that depth | Decode |
|---|---|---|---|---|
| 49152 | 14 585 MiB after a short request | not measured | | 59 tok/s, 66 % drafts accepted |
| 65536 | 15 143 MiB | 15 303 MiB, GTT 381 MiB | 737 tok/s | 59 tok/s |

The 64K example leaves little VRAM headroom. The launcher ships 65536; reduce it to 49152 or lower if other GPU clients need memory, and remeasure before choosing a limit. Which file is which, the Swift 1.5 post-train, and the sampling and reasoning-effort defaults are in [common/02](../common/02-model-choice-and-speculation.md) sections 3 and 6.

Differences from the Windows launcher, each deliberate:

- **No `-lm none`.** On Windows it stopped the loader from mapping 11 GB into a 16 GB machine. On Linux the default memory-mapped load is the right one: the file sits in the page cache, is evictable, and a restart reloads from cache in seconds. If a memory monitor showing 11 GB of "used" bothers you, `-lm none` works here too and costs nothing but the fast restart.
- **`--device`.** The packaged build and the step 2 build both contain two backends. Without the flag llama.cpp picks one on its own; pinning it keeps benchmarks and daily use on the same backend.
- **One environment variable, as insurance.** The script exports `ROCBLAS_USE_HIPBLASLT=0`. The 96 small BF16 tensors in Qwen3.5/3.8 files go through rocBLAS, and on the Windows SDK rocBLAS forwards them to hipBLASLt, which crashes on gfx1201. Whether Arch's rocBLAS 7.2 does the same is unverified; the variable is harmless when it is not needed and the Vulkan backend ignores it. `HSA_OVERRIDE_GFX_VERSION` is unnecessary on ROCm 7.2 for gfx1201 and harmful if wrong. `HIP_VISIBLE_DEVICES` only matters with two AMD cards.

---

## 2. Starting it from Sway

The launcher is meant to run in a visible terminal, as on Windows: no daemon, nothing to debug when it fails, Ctrl+C or closing the window stops it. In `~/.config/sway/config`:

```
bindsym $mod+F9 exec foot --title llama-server $HOME/llm/start-llm.sh
bindsym $mod+F10 exec $HOME/llm/close-llm.sh
for_window [title="llama-server"] move to scratchpad
```

`foot` is the terminal from the Arch guide's Sway step; any terminal works. The scratchpad rule parks the window out of the way; `$mod+Shift+minus` / `$mod+minus` shows and hides it. Closing the window sends SIGHUP, which llama-server handles like Ctrl+C: it exits cleanly in under a second and the kernel frees VRAM when the process ends. Nothing is written to disk that could be lost.

Second model: copy `start-llm.sh` to `start-<name>.sh`, change `MODEL=` and the per-model flags, add a keybinding. The port check in the script refuses to start a second server while one is listening.

### Use the PC's model from a laptop

Run Code on the laptop and point its model connection at the PC. The PC handles model inference using its GPU/RAM; Code's file edits, terminal commands, and MCP tools execute on the laptop, where the project is open. Project context is sent to the PC as part of the model requests. Opening the server's browser chat alone does not give it access to the laptop's files.

With [the launcher script](scripts/start-llm.sh) installed as `~/llm/start-llm.sh`, run it on the PC:

```bash
~/llm/start-llm.sh
```

The launcher listens on all IPv4 interfaces at port 18080 by default, with no API key configured. On the PC, use `http://127.0.0.1:18080`. For localhost-only access, launch with `~/llm/start-llm.sh --local`. The binding uses llama.cpp's documented [host flag](https://github.com/ggml-org/llama.cpp/tree/master/tools/server).

In another PC terminal, find its LAN address:

```bash
ip -br -4 address show scope global
```

Choose the address on your Ethernet/Wi-Fi interface, not a Docker bridge. For example, if the PC is `192.168.1.50`, the laptop can open `http://192.168.1.50:18080` for browser chat. `0.0.0.0` is a listening address, not the address to enter on the laptop.

On the laptop, follow [Code's model setup](../common/04-code-oss-setup.md#2-add-the-local-model) with these values:

| Field | Laptop value (replace the example IP) |
|---|---|
| API type | Chat Completions |
| Model ID | `swift-qwen` |
| Request URL | `http://192.168.1.50:18080/v1/chat/completions` |
| API key | Leave empty, or use `local` if the client requires a value |
| Context / output | Match the PC server; the supplied launcher uses 65536 / 8192 in Code |

`local` is only a client placeholder; the server does not validate it. Clients asking for an OpenAI **base URL** instead of a complete request URL use `http://192.168.1.50:18080/v1`.

From the laptop, check connectivity:

```bash
curl -fsS http://192.168.1.50:18080/health
curl -fsS http://192.168.1.50:18080/v1/models
```

Expect `ok` from health and `swift-qwen` in the model list. Then open a project on the laptop, select Agent and this model, and run section 3's file-read test in the Code guide.

This default is for a trusted home LAN: any device that can reach port 18080 can use the model, and HTTP does not encrypt prompts or responses. Do not forward this unauthenticated port through the router. If the PC's firewall blocks access, allow inbound TCP 18080 from the laptop's LAN IP using your existing firewall. A guest Wi-Fi network or client isolation can also prevent the devices from connecting. A router DHCP reservation keeps the PC's address stable.

The launcher uses `-np 1`: PC and laptop requests share one inference slot and may wait for each other. Both clients use the same loaded model. For web search, the laptop's MCP adapter can use SearXNG on the PC at `http://<PC-LAN-IP>:8888`; see [the search setup](../common/04-code-oss-setup.md#4-optional-add-free-local-web-search).

---

## 3. Optional: systemd user unit

For a server that should come up at login without a window. It is the one place this guide uses a service, because on Linux a user unit is three lines and `journalctl --user -u llm` is a better log than a terminal.

```bash
cp ~/llm/scripts/llm.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user start llm           # stop / restart / status / enable
journalctl --user -u llm -f
```

The unit runs the same `start-llm.sh`, so flags live in one place. Do not run the unit and the keybinding at the same time; the port check in the script refuses the second one.

---

## 4. What to re-measure, and the five-minute procedure

```bash
~/llm/scripts/bench.sh ~/llm/models/MODEL.gguf ROCm0 512,2048 0,16384 512,1024
~/llm/scripts/bench.sh ~/llm/models/MODEL.gguf Vulkan0 512,2048 0,16384 512
```

Arguments: model, device, prompt sizes, context depths, micro-batch sizes. Read the table the same way as in the Windows guide:

- `pp2048 @ d16384`: the micro-batch with the higher number wins. On ROCm this was 512 by a wide margin (905 vs 266 tok/s); confirm it, and measure it separately on Vulkan where the kernels differ.
- `tg32 @ d16384`: the decode speed an agent sees after a few turns. Compare the two devices here; this is where Vulkan may win.
- Pick `DEVICE=` in the launcher from the column that matters for your use: prompt processing for coding agents, decode for chat.

VRAM: `cat /sys/class/drm/card*/device/mem_info_vram_used` while the server is idle after one request, divided by 1024² for MiB. Must stay under about 15 300 MiB on a 16 GB card; above that the kernel's GTT fallback silently moves buffers to system RAM over PCIe and speed collapses, the same failure as Windows' shared-memory spill. `--no-context-shift` makes an out-of-memory at load time a clean error rather than a slow server.

The draft head: send one prompt that asks for a few hundred tokens of new code and read `draft_n_accepted` against `draft_n` in the response timings, plus the decode tok/s. On Windows the same file accepted 76 % and decoded at 48 to 50 tok/s; on Vulkan0 on the benchmark configuration the first run gave 66 % and 59 tok/s at `--spec-draft-n-max 3`. Sweep 2 to 4 if you want to confirm it. The context ceiling is measured in section 1; re-check it with the same VRAM read whenever the desktop beside the server changes.

The meta-prompt in [common/02](../common/02-model-choice-and-speculation.md) and the Windows guide's launch file apply unchanged; only the fixed-flags block changes to the Linux launcher above.

---

## 5. Stopping

`~/llm/close-llm.sh`, `$mod+F10`, Ctrl+C in the window, or closing the window. The script sends SIGINT, waits up to five seconds, sends SIGKILL only if the process is still there, then waits for the port to clear and reports anything else holding 18080 without killing it.
