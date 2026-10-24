# Reality check: what would still help, and what to watch

## What this file is

Shared by the Windows and Linux guides; the numbers were measured on Windows and the ROCm backend on Linux runs the same kernels. The measured speed of the benchmark configuration set against hosted models, an honest placement of what a 27B local model can and cannot do for coding work, the remaining levers in order of impact, and the model classes and tools worth watching. Numbers for the example configuration are measured (October 2026). Numbers for hosted services are rough public ranges that change monthly; read them as orders of magnitude.

---

## 1. What the benchmark configuration does

27B hybrid-attention model at IQ3_S (12 GB with the draft head), 49k context, q8_0 KV, draft-head speculation, single user:

| Metric | Value | Note |
|---|---|---|
| Prompt processing | ~1 000 tok/s fresh, ~800 tok/s at 28k depth | a 10k-token prompt takes ~10 s |
| Decode, fresh text | ~49 tok/s | about 35 words per second; 32 without the head |
| Decode at 28k depth | ~40 tok/s | holds up |
| Decode, edits and repeats | up to ~176 tok/s | only with the plain file and n-gram speculation; not measured with the head |
| Context | 49k | 65k with the plain file |
| Cost per token | electricity | ~300 W under load |
| Data leaving the machine | none | |

---

## 2. Against hosted frontier models

### Speed

| | The example configuration | Frontier API (typical) | Fast-inference hosts running open models |
|---|---|---|---|
| Decode | 49 tok/s | ~40–120 tok/s, varies with load | 500–2 000+ tok/s |
| Prefill of a 10k prompt | ~10 s | ~1–3 s, near zero with prompt caching | under 1 s |
| Time to first token | ~0.1 s + prefill | 0.5–2 s + queue | ~0.2 s |
| Context | 49k | 200k–1M | 32k–128k |

On decode the machine is within 1 to 2× of a frontier API. On prefill it is 3 to 10× slower, and that is the part that hurts in agent loops because every turn resends the whole conversation. Prompt-cache reuse (Windows step 2 section 7, Linux step 3) is the fix, and it matters more than any kernel work.

### Quality

A 27B model at 3.4 bits is not a frontier model, and no flag changes that. Placement for coding-agent work:

| Task | Local 27B | Frontier |
|---|---|---|
| Single-file edits, boilerplate, tests, docstrings, regex, shell one-liners | good, often indistinguishable | good |
| Explaining unfamiliar code across a 20-file repository | decent | better |
| Multi-file refactor with a plan, tool calls over 30+ turns | inconsistent; needs supervision; malformed tool calls appear at depth | reliable |
| A subtle concurrency or build-system bug | usually fails or loops | usually succeeds |
| Anything where being wrong is expensive | not the tool | the tool |

A split that works: the local model for the frequent small interactions, a hosted model for the hard ones, with the local server as the fallback when offline, rate-limited, or working on material that must not leave the machine.

### Cost

A heavy agent day on a hosted API commonly costs tens of dollars. The same day locally costs well under a dollar of electricity. The GPU pays for itself quickly on tasks the local model handles, and never on tasks it cannot.

---

## 3. What would still make it faster

Cheapest and largest first:

1. **`--cache-reuse 256`, once it is possible.** Per-turn prefill of a 40k conversation would go from ~40 s to ~1 s. It needs the server's prompt cache, and on this model the prompt cache's state save crashes the server, so the cache is off (Windows step 2 section 7, Linux step 3). Worth re-testing on each new llama.cpp release; it is the largest remaining win for agent loops.
2. **Less thinking.** On a thinking model most of the wait is the hidden reasoning before the answer. The Swift 1.5 post-train in the launchers cuts it by a quarter to a half; the next step is a client that sets the reasoning effort to low for trivial questions (model-choice file, section 3.3).
3. **A smaller or mixture-of-experts model.** Decode is bandwidth bound. A ~16B-total / ~3B-active MoE at Q4 (~9 GB) would decode at 100+ tok/s with quality near a 14B dense model. Watch for MoE releases in the 8 to 12 GB range.
4. **Fan curve.** Memory junction sat at 88 to 90 °C under sustained load; GDDR6 begins throttling in the mid-90s. A steeper curve costs nothing.
5. **Resizable BAR / Smart Access Memory** on in the BIOS. Mostly helps load time and host transfers.
6. **32 GB of host RAM.** Not for speed: it allows building and serving at the same time, and stops the ~14 GB host commit of a loaded model from crowding everything else.
7. **A newer llama.cpp every few weeks.** RDNA 4 kernel work is active; with the build scripts of either guide a rebuild is a 40-minute background job.

Not worth the time, all tested or verified irrelevant on this GPU: more CPU threads, hipBLASLt variables, `GGML_CUDA_FORCE_MMQ`, rocWMMA flags, larger `-ub`, more server slots.

---

## 4. Model classes to watch (fit in 16 GB, worth a download)

Names change fast; the classes don't.

| Class | Why | On the example configuration |
|---|---|---|
| Hybrid-attention 20–30B dense (Qwen3.5 27B, GLM Flash class) | small KV cache, so 65k fits; best quality per GB of VRAM today | the current choice |
| MoE with ≤ 4B active parameters and a file ≤ 10 GB | 3× decode at 14B-class quality | would take over day-to-day editing |
| Coder-tuned 14B at Q4_K_M (Qwen-Coder, Devstral class) | tool-call training; Q4 removes most quantization damage | ~40 tok/s, better tool-call discipline |
| Gemma 4 / Gemma 3 at 12B–27B | strong general assistant, image input | heavier KV cache than Qwen3.5 |
| Draft models or MTP heads matching the main model | 1.5× decode on fresh text measured here, up to 3× reported | the current file's mtp twin is in the launchers; a separate draft only once VRAM allows it |

Avoid: files over 13 GB (nothing else fits beside them), IQ2 quants of 70B models (slow and worse than a good 14B), and GGUF conversions under two weeks old with open issues on the llama.cpp tracker.

Whether the current model and file are the right pick for a GPU in the recommended class, what the Swift 1.5 post-train changes, and what the draft head costs in context window, are worked through in [02-model-choice-and-speculation.md](./02-model-choice-and-speculation.md).

---

## 5. Tools around the server

| Tool | What it adds | Notes |
|---|---|---|
| llama-server's built-in web UI (`http://127.0.0.1:18080`) | chat, zero setup | |
| Cline (VS Code) | agent with file and terminal tools | provider "OpenAI compatible", base URL `http://127.0.0.1:18080/v1` |
| Zed | fast editor with a native llama.cpp provider | [Swift model setup and settings](./03-zed-setup.md) |
| Code OSS / VS Code built-in agent | file edits and terminal tools in Chat | [Custom Endpoint setup for Swift](./04-code-oss-setup.md); requires a build with that provider |
| llama-swap | several models behind one port, swapped on demand | useful with two or three models; still one at a time |
| Continue, Aider, OpenCode | other agents; Aider is strong for tight edit loops | all speak the OpenAI API |
| LM Studio | GUI with its own ROCm / Vulkan build | fine for trying models; updates slower than a local build |
| llama.cpp Vulkan backend | needs no ROCm; the official zip just works | 10 to 30 % slower than this HIP build on RDNA 4; the fallback if a driver update breaks ROCm |

The URLs above use the Linux launcher’s port 18080; the Windows launcher uses 8080.

---

## 6. In one paragraph

The GPU is no longer the bottleneck; the model is. The example configuration runs a 27B model faster than it can be read, with more context than most editors fill, offline and for free. It is a capable junior pair that needs review, not a senior that works unsupervised. Future effort belongs in prompt-cache reuse and model choice, not in kernels or flags. The build and launch recipes in steps 1 and 2 are solved; rerun them rather than re-deriving them.
