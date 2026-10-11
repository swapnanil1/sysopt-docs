# Which model, which file, and the speed trick that trades context for tokens per second

## What this file is

Shared by the Windows and Linux guides. The [reality check](./01-reality-check.md) said the model is now the bottleneck. This file answers the follow-up: is the model on the reference machine the right one, is the *file* the right one, and what the one remaining large speedup costs. It is written for someone new to running models locally, so the terms are explained before they are used.

Reference setup: RX 9070 16 GB, 16 GB of RAM, Qwen3.8-27B in its Swift 1.5 post-train, as a GSQ-RCO IQ3_S GGUF with the draft head (12 GB), used for agentic coding through Cline and Zed. October 2026.

---

## 1. Three words that decide everything

**Context.** The model sees a fixed window of text at once, measured in tokens (roughly three quarters of a word each). Everything an agent sends, every file it reads, every tool result and every reply must fit in the window. When it fills, the oldest text drops out and the model forgets it. The reference machine runs a 49k-token window with the draft head, about 37 000 words, or 65k without it.

**Decode speed.** How fast the model writes its answer, in tokens per second. The reference machine writes about 49 tokens per second on new text with the draft head and 32 without it, both faster than a person reads.

**Quantization.** A 27B model is 27 billion numbers. At full precision that is 54 GB and does not fit any consumer card. A quantized file stores each number in 3 to 4 bits instead of 16, at a small cost in accuracy. The method used to decide *how* to round matters almost as much as how many bits are kept.

---

## 2. Is a 27B dense model the right class for 16 GB?

Yes. The candidates that fit a 16 GB card were compared on three axes: coding quality, VRAM left for context, and decode speed.

| Model | File | Why it loses to Qwen3.8-27B here |
|---|---|---|
| Qwen3.8-27B (current) | 11.8 GB at 3.5 bpw, 12.1 GB with the draft head | hybrid attention: a very small KV cache, so 49k to 65k context fits beside the weights |
| Devstral Small 2, 24B dense | 10.7 GB at IQ3_M | the only model in class with a higher agentic-coding score, but a conventional KV cache about 4× larger per token, so about 24k context; at 3-bit it loses the edge its headline score was measured with |
| gpt-oss-20b, MoE | 12.8 GB native MXFP4 | roughly 3× faster decode (3.6B active parameters), a tier lower on coding quality, a tool-call format that agents find more fragile |
| Qwen3.6-35B-A3B, MoE | 13.2 GB at IQ3_XXS, 17.7 GB at IQ4_XS | 3 to 4× faster decode and a flat memory curve, but a 3-bit MoE scores below a 3.5-bit dense 27B on coding, and the 4-bit file does not fit |
| Muse Glimmer 30B, dense | 16.8 GB at Q4_K_M official, ~14 GB in community IQ3_XXS | 2 KV heads and sliding windows make context nearly free, but it lost 24/30 to Qwen3.8-27B's 30/30 in a controlled agent test at half the speed, and only Q4 files are official |
| Gemma 4 26B-A4B and 31B | 17 to 18 GB at Q4 | do not fit |

Qwen3.8 has no model between 27B and 180B, so there is no "slightly smaller Qwen3.8" to fall back to. The 27B is the top of what this card can hold, and its small KV cache is what makes long context possible on it.

---

## 3. Is the file the right one?

Three things about the specific GGUF on the reference machine.

### 3.1 The compression is the good kind

The file uses GSQ-RCO, a quantization method from a research lab (ISTA-DASLab). It runs an optimization step that chooses roundings to keep the model's behaviour as close to the original as possible. Standard llama.cpp quants (the bartowski and unsloth files most people download) use an importance matrix instead. Both are good; the research method generally loses a little less accuracy at the same size. The maker's own table puts IQ3_S level with the unquantized model on AIME25 and LiveCodeBench and half a point under it on GPQA-Diamond, and IQ3_XXS one point lower on LiveCodeBench for 1.7 GB less. The difference between the two files is measurable in a benchmark and rarely visible in a conversation.

### 3.2 Take the twin with the speed helper

Standard Qwen3.8-27B files carry an extra block, numbered 64 after the 64 real layers, called a multi-token-prediction (MTP) head. It is a small built-in model that guesses the next few tokens. llama.cpp uses it as a free speculator with `--spec-type draft-mtp`.

The GSQ-RCO repos publish every quant twice: `...IQ3_S.gguf` (11.8 GB) without the head and `...IQ3_S-mtp.gguf` (12.1 GB) with it. The 64 real layers are quantized identically in both; the mtp file only appends the 15 tensors of the head, 0.35 GB. Loaded without the draft-mtp flag the two files behave the same, and the head is dead weight. Both launchers in these guides name an mtp file and set the flag. The plain file is the right one only when the head cannot be afforded, which on 16 GB means a context window above about 49k (section 5).

Check any GGUF in thirty seconds:

```powershell
.\llama-gguf.exe .\model.gguf r n 2>&1 | Select-String 'name = blk\.64\.' | Measure-Object
```

A count of zero means no MTP head: use `--spec-type ngram-mod` with that file, never `draft-mtp`.

### 3.3 The Swift 1.5 post-train

UkisAI took Qwen3.8-27B through further reinforcement learning and on-policy distillation with one aim: fewer thinking tokens before the answer. Its GGUF repo, `ukisai/Swift-1.5-Qwen3.8-27B-GSQ-RCO-GGUF`, reuses ISTA-DASLab's per-tensor allocation, so the files are the same size, take the same flags and come in the same plain and mtp twins. `Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf` is a drop-in for the file in 3.2, and it is what both launchers ship.

The maker's table, unquantized weights, five seeds, against base Qwen3.8-27B:

| Benchmark | Qwen3.8 | Swift 1.5 | Thinking tokens, mean |
|---|---|---|---|
| LiveCodeBench v6 | 76.8 | 81.7 | 25 % fewer |
| Terminal-Bench 2.1 | 69.2 | 72.1 | 16 % fewer |
| GPQA-Diamond | 88.3 | 88.6 | 42 % fewer |
| AIME 2026 | 98.7 | 96.0 | 40 % fewer |
| IFBench | 73.5 | 72.1 | 39 % fewer |
| ERQA | 67.5 | 65.4 | 54 % fewer |

Coding and terminal tasks up, maths and strict instruction following slightly down, a quarter to a half less thinking everywhere. On a card that writes 40 to 50 tokens per second the thinking is most of the wait, so for agent work the token column matters more than the score column. For a maths-heavy or instruction-exact job the plain Qwen3.8 file is the same launcher with one file name changed.

What to hold against it: every number is the maker's, with no independent evaluation yet; the quant's own divergence table says its IQ3_S sits a little further from its unquantized weights than ISTA's does from Qwen's, checked at 512 tokens of context only; the licence is the Swift Open License v1.0, free for personal use and for organisations under one million dollars of revenue, with the base model staying Apache 2.0; and the repo is gated, so the download needs a Hugging Face account with access granted.

**Reasoning effort.** The chat template in the file has a switch with three settings, xhigh, medium and low, and defaults to xhigh when a request does not set one. At xhigh it adds one instruction to think carefully and check assumptions; medium adds nothing; low asks for brief thinking. Swift was trained and benchmarked at xhigh, where it matches or beats the base model. At medium it scored two points below the base. There is nothing to set: without a request-level override every request runs at xhigh. Do not set medium. Low still scored above the base on GPQA and is the setting for short answers; server-wide it is `--chat-template-kwargs "{\"reasoning_effort\":\"low\"}"`. Leave `--reasoning-budget` at its default of unlimited: the model was trained to think less on its own, and a hard cut mid-thought is what the medium regression looks like.

---

## 4. How the speed trick works (one main model plus one helper)

Decode is slow because writing each token means reading all 11 GB of weights from memory once. Memory speed is the limit, not compute. Speculative decoding gets around that:

1. A small helper guesses the next few tokens in one go.
2. The big model checks all of them in a single pass, which costs about the same as writing one token.
3. Every guess that matches is kept. The first wrong one is discarded and the big model continues from there.
4. The head's guesses were accepted 76 to 80 % of the time on code on the reference machine, so three tokens come out for the price of two.

The output does not change. The big model still decides every token; the helper only proposes. A rejected guess costs one wasted check, nothing more.

`--spec-type ngram-mod` is a version of this without a helper model. It looks back in the conversation for text that repeats, which is why rewriting a file ran at 176 tokens per second on the reference machine while fresh text stayed at 32. The MTP head can guess new text too, which is what lifts the fresh-text number. The server takes one speculation type per launch, so the two are not combined.

This is not two independent models. The helper never answers; it only exists to make the main model faster. Running two full models at once on 16 GB is not possible; tools such as llama-swap load one at a time on demand.

---

## 5. What it costs: memory, and therefore context

The head lives in GPU memory next to the main model: 0.35 GB of weights plus its own cache and working buffers. Measured on the reference machine at 49k context, idle after one request: 15 573 MB dedicated and 870 MB shared, against 14 955 MB and 660 MB for the plain file at 65k. The head costs about 0.8 GB in total. At 65k with the head, shared memory rose to 1 081 MB, which is the start of the spill into system RAM. That is why the launchers run the mtp file at 49k; 40k freed almost nothing and is not worth the window.

Whether the trade is worth it depends on how the model is used:

- A coding agent works in turns: read a file, edit it, run a test, read the result, continue. Each turn adds a little. A 30-turn session on one project usually uses 20k to 30k tokens, which fits in 49k with room. Here the user spends most of the session waiting for the model to write, so faster decode is what they notice.
- Pasting a whole codebase into one message, or reading 40 files in a row, can need 50k tokens or more. That fits in 65k and not in 49k; the model forgets the first files before it finishes the last. Here the bigger window is what matters and speed does not help.

---

## 6. The three options

| | A: the mtp twin | B: the plain twin | C: a separate draft model |
|---|---|---|---|
| Download | `...IQ3_S-mtp.gguf`, 12.1 GB | `...IQ3_S.gguf`, 11.8 GB | the plain twin plus a 1.1 GB DFlash 2 draft (`incoai/Qwen3.8-27B-DFlash2-GGUF`, Q4_K_M) |
| Flag | `--spec-type draft-mtp --spec-draft-n-max 3`, plus `--cache-ram 0` and `ROCBLAS_USE_HIPBLASLT=0` (see below) | `--spec-type ngram-mod`, plus `--cache-ram 0` | `--spec-type draft-dflash -md <draft.gguf>` |
| Weights | GSQ-RCO IQ3_S | the same | the same |
| Memory cost | about 0.8 GB (measured) | 0 | ~2.7 GB (reported) |
| Context on 16 GB | 49k at q8_0 KV (measured); 65k spills | 65k at q8_0 KV (measured) | roughly 32k |
| Fresh-text decode | 48 to 50 tok/s, 40 with 28k tokens in context (measured) | 32 tok/s (measured) | ~2.3× reported, no AMD numbers |
| Edits and repeats | not measured | 176 tok/s (measured) | not reported |
| Prompt processing | 809 tok/s at 28k depth, unchanged | unchanged | unchanged |
| Where it stands | what both launchers ship | the fallback for sessions that need the full 65k | no reason to try first now that the mtp twins exist |

The measurements behind A, all on the reference machine with the Swift file, one 700-token code answer each, then one 28 402-token prompt:

| Context | `--spec-draft-n-max` | Decode | Drafts accepted | Dedicated | Shared |
|---|---|---|---|---|---|
| 49k | 2 | 48 to 50 tok/s | 76 % | 15 573 MB | 870 MB |
| 49k | 3 | 49 | 68 % | 15 731 MB | 871 MB |
| 49k | 4 | 51 | 65 % | 15 873 MB | 872 MB |
| 65k | 2 | 49 | 76 % | 16 068 MB | 1 081 MB |
| 49k, 28k-token prompt | 2 | 40 | 80 % | 15 594 MB | 874 MB |

Deeper drafting bought 3 tok/s for 300 MB on a card that is already full, inside run-to-run noise.

Two things changed after that table was measured, and both launchers now carry them:

- **`ROCBLAS_USE_HIPBLASLT=0`.** The runs above went through hipBLASLt for the model's 96 BF16 tensors. On a later session hipBLASLt crashed on gfx1201 at the first draft step, reproducibly (access violation in `libhipblaslt.dll`). With the variable at 0 rocBLAS uses its own kernels, which need a few hundred MB of workspace at the first task: **49k at q8_0 then ran out of VRAM**, and 32k at q8_0 measured 14 938 MB dedicated. So the launchers ship 32k, or 49k with q4_0.
- **`--cache-ram 0`.** The server's prompt cache saves a slot's state to RAM before every new task, and on this model that save throws and kills the server on the second request. With it off, measured on the Swift file at 32k, q8_0, `--spec-draft-n-max 3`: 62 tok/s on fresh code (90 % accepted), 44 tok/s on prose (54 %), 64 tok/s on a code rewrite (97 %), five requests back to back. That is why the launchers moved from 2 to 3; at 32k the 300 MB is affordable.

The same four steps give the answer on any other card:

1. Start the server with the mtp file as the launcher ships it. Send one prompt that asks for a few hundred tokens of new code. Read `draft_n` and `draft_n_accepted` in the response timings; above about 55 % accepted it is paying for itself. Read the decode tok/s in the same place.
2. Check memory while the server is idle after that request: on Windows, Task Manager → GPU → *Shared GPU memory*; on Linux, `mem_info_vram_used`. Shared memory that rises when the context is raised is the spill; compare against the plain file at the same window.
3. Repeat with `--spec-draft-n-max 3` and `4`. Keep the fastest only if it is clearly outside noise.
4. Then try `-c 65536`. If step 2 still passes, keep it. If not, go back to 49152, or keep 65536 with `-ctk q4_0 -ctv q4_0`, which costs nothing in speed but is the first suspect when tool calls go wrong deep into a session.

---

## 7. In one paragraph

The right model for a 16 GB card doing agentic coding is Qwen3.8-27B, and the GSQ-RCO file is a slightly better compression of it than the standard downloads. The makers publish each quant with and without the model's built-in speed helper, and the version with it is the one to download: same weights, 0.35 GB more, and with `--spec-type draft-mtp` about one and a half times the writing speed on new text, 32 to 49 tokens per second here, for a smaller context window, 49k instead of 65k. The Swift 1.5 post-train of the same model thinks a quarter to a half less before answering and scores higher on coding, so it is the launcher default; the plain Qwen3.8 file with `ngram-mod` is the right answer for sessions that need the whole 65k, and the plain Qwen3.8 weights for maths-heavy work.
