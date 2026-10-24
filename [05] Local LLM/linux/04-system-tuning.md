# Step 4: System tuning for throughput, and what the Arch guide already did

## What this step is

What on a CachyOS box affects llama.cpp throughput, ordered by expected effect, and which of it the [Arch guide](../../[01]%20OS/[01]%20ArchAIO.md) already configured. Most of this list is "already done" or "does not matter"; the honest expected gain from everything here together is a few percent, against the 2 to 5× that the flags in step 3 give. Read it once, apply the two or three lines that apply, and do not revisit.

---

## 1. Already in place from the Arch guide (do not duplicate)

| Item | Where | Effect on inference |
|---|---|---|
| zram swap, `vm.swappiness=150`, no swapfile | arch/06 `cachyos-settings` | correct for this workload; VRAM is not mirrored in RAM on Linux, so nothing large ever swaps |
| `ananicy-cpp` with CachyOS rules | arch/06 | keeps the desktop responsive during prompt processing; no rule needed for `llama-server`, it is GPU-bound and its CPU threads idle-spin at low cost |
| `linux-cachyos` with the BORE or sched-ext scheduler | arch/07 | neutral for a GPU-bound process; fine |
| `iommu=pt` on the SAFE command line | arch/07 | correct: identity-mapped IOMMU is what you want for PCIe DMA from the GPU; `amd_iommu=off` (MAX) is equally fine |
| `vulkan-radeon` (RADV), no `amdvlk` | arch/04 | the Vulkan backend needs exactly this |
| LACT with `amdgpu.ppfeaturemask` for OverDrive | arch/04, arch/07 | the tool for section 2 below |
| `power-profiles-daemon` pinned to performance (MAX) or `game-performance` wrapper (SAFE) | arch/09 | CPU side; small effect, see section 3 |

---

## 2. GPU: the only knobs with a measurable effect

Decode is bound by VRAM bandwidth, prompt processing by compute. Both respond to GPU clocks and both throttle on memory-junction temperature. In LACT (`lact gui`, daemon from arch/04):

1. **Power limit** to the card's maximum. The RX 9070 ships below its board limit on some vendors' defaults; a higher limit keeps clocks up during sustained prompt processing.
2. **Fan curve** that keeps the memory junction under ~90 °C. On Windows the same GPU class sat at 88 to 90 °C under sustained load, right at the point where GDDR6 begins to throttle. A curve reaching 70 to 80 % fan by 85 °C junction costs noise and nothing else.
3. **Performance level**: leave on `auto`. Forcing `high` holds boost clocks while idle, which heats the card between requests for no throughput gain; the driver already ramps within a few milliseconds of a kernel launch.

LACT applies these at boot via `lactd`. Confirm under load:

```bash
cat /sys/class/drm/card*/device/hwmon/hwmon*/temp3_input       # memory junction, millidegrees
cat /sys/class/drm/card*/device/pp_dpm_mclk                    # memory clock, '*' marks the current state
```

**Resizable BAR**: check once, it affects load time and host-to-device copies more than steady state:

```bash
sudo dmesg | grep -i 'BAR.*resiz'        # amdgpu reports a resized BAR 0 of 16384M when it is on
```

If absent, enable *Resizable BAR* / *Above 4G Decoding* in your motherboard firmware; names and availability vary by board.

---

## 3. CPU: small, mostly already handled

With every layer on the GPU the CPU does tokenization, sampling, the HTTP server and the thread that feeds the GPU. The one thing that shows up is latency to the GPU queue, which is why the launcher uses `-t 6` (the physical cores) and not 12: SMT siblings add contention, not throughput, for this workload.

- `powerprofilesctl set performance` while serving, if arch/09's MAX option is not in use. The SAFE alternative is `game-performance ~/llm/start-llm.sh` from the keybinding, which does the same for the server's lifetime.
- `GGML_NATIVE=ON` in the step 2 build already tunes the CPU-side kernels for Zen 2.

---

## 4. Memory

- **Transparent huge pages**: the kernel default on CachyOS is `madvise`; llama.cpp asks for huge pages on its own allocations where it helps. Do not set `always` on the command line; the Arch guide already lists it as a no-op for games and it can cost latency here.
- **`vm.max_map_count`**: Arch's `1048576` is plenty; never lower it (arch/09).
- **Page cache**: the memory-mapped model file occupies up to 11 GB of cache. This is evictable and correct; do not "free" it with `drop_caches`, the next load would re-read the file from disk.
- **GTT size** (`amdgpu.gttsize`): irrelevant while the model fits in VRAM, which the step 3 VRAM check guarantees. It only matters for a model that is deliberately split between VRAM and RAM, which this guide does not do.

---

## 5. Things that do not help, verified or by design

- `HSA_OVERRIDE_GFX_VERSION`: not needed on ROCm 7.2 for gfx1201; a wrong value selects wrong kernels.
- `ROCBLAS_USE_HIPBLASLT`, `GGML_CUDA_FORCE_MMQ`, rocWMMA flags: no effect on RDNA 4, the MMQ and WMMA paths are already the chosen ones (Windows build file, 7.3).
- More `-t`, more HTTP threads, more slots (`-np`): no gain, and `-np 2` does not fit in VRAM at 65k.
- A swapfile beside zram: nothing in this workload swaps; the earlier Windows pagefile growth was a WDDM artefact.
- Realtime priority or `nice -n -10` for the server: the GPU does not care; the desktop would.
- `mitigations=off` and the rest of the MAX command line: a few percent on CPU-bound work, nothing measurable on GPU inference.

---

## 6. In one paragraph

On CachyOS the system is already tuned for this by the Arch guide; what remains is a fan curve and a power limit in LACT, confirming Resizable BAR once, and keeping `-t` at the physical core count. Everything with a large effect lives in the launcher flags (step 3) and in the backend choice (step 2, section 6), and both of those are measured, not configured.
