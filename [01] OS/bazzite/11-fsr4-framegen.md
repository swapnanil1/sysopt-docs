# Step 11 — FSR 4 / Redstone ML frame generation in Proton games (AMD RDNA3/RDNA4)

## What this step is

FSR 4 **upscaling** needs nothing on RDNA4 (RX 9000) any more: pick Proton-CachyOS or Proton-GE for the game and it is handled.

FSR **ML frame generation** ("Redstone", frame-gen 4.0.x) is one launch option away in most games — but which option depends on *how the game ships FSR*. Look in the game folder first; that decides everything below. No files are copied into game folders unless the automatic path fails.

Verified against Proton-CachyOS `cachyos-11.0-20260703` and GE-Proton11-7 (both carry the same `protonfixes/upscalers.py`). Community mechanism, not supported by AMD, Valve or Bazzite. Re-check after Proton or game updates.

## 0. Prerequisites

- RDNA4 (RX 9000) for the native path; RDNA3 (RX 7000) works with two extra variables (below). Older AMD cards and other vendors: not covered.
- Mesa 25.2 or newer (`vulkaninfo --summary | grep -i driver`). Any current Bazzite, CachyOS or Arch qualifies.
- Proton-CachyOS or Proton-GE installed (ProtonUp-Qt from Flathub, or unpack into `~/.steam/root/compatibilitytools.d/` and restart Steam). Valve's own Proton does none of this.
- DX12 games only.

## 1. Find out which kind of game you have

```bash
G="/path/to/steamapps/common/<Game>"
find "$G" -iname 'amd_fidelityfx*.dll' -printf '%s\t%p\n'
```

| You see | Game type | Frame-gen path |
| --- | --- | --- |
| **only** `amd_fidelityfx_dx12.dll` (~6.7 MB) | FSR 3.1, "SDK 1.x" — the common case (Cyberpunk 2077, GTA V Enhanced, most 2024–2025 titles) | **A** — driver library, nothing to copy |
| `amd_fidelityfx_loader_dx12.dll` + `amd_fidelityfx_upscaler_dx12.dll` + `amd_fidelityfx_framegeneration_dx12.dll` | FSR 4 "SDK 2.x" — newer titles | **B** — component DLL upgrade |
| nothing | game has no FSR DLL model (static link, or DLSS/XeSS only) | **C** — OptiScaler |

How this works: an SDK 1.x game's `amd_fidelityfx_dx12.dll` asks the graphics driver for an "AMD driver-based FidelityFX library" (`amdxcffx64.dll` on Windows). Proton-CachyOS/GE ship a small stand-in (`amdxc64.dll`) that answers that request with a real `amdxcffx64.dll` it places in the prefix's `system32` **on every launch, for every game, automatically**. The current one (v4.1.1, 65 MB) contains FSR 4.1.1 upscaling *and* the 4.0.1 ML frame generator. The launch options below only tell it which parts to switch on.

## 2A. SDK 1.x game (only `amd_fidelityfx_dx12.dll`)

Steam → game → Properties → Compatibility → force Proton-CachyOS (or GE). Launch options:

```
PROTON_MLFG_UPGRADE=1 PROTON_FSR4_INDICATOR=1 %command%
```

- `PROTON_MLFG_UPGRADE=1` — switch the driver library's ML frame generation on (README: "MLFG with FSR4 ≥ 4.0.3"; the bundled 4.1.1 qualifies).
- `PROTON_FSR4_INDICATOR=1` — top-left watermark for upscaler *and* frame gen. Remove once confirmed.
- `PROTON_FSR4_UPGRADE=1` is no longer needed on RDNA4 with these builds; harmless if present.
- RDNA3 only: add `PROTON_FSR4_RDNA3_UPGRADE=1 DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`.
- If the game's own `amd_fidelityfx_dx12.dll` is older than `1.0.1.41314` (check: `strings -el amd_fidelityfx_dx12.dll | grep -A1 FileVersion`), add `PROTON_FFX3_UPGRADE=1` so Proton substitutes that version — older 3.1 builds don't ask the driver for the upgrade.

Nothing is copied into the game folder. Steam "Verify integrity" changes nothing here; removing the launch option is the undo.

## 2B. SDK 2.x game (loader + upscaler + framegeneration DLLs)

Same compatibility tool. Launch options:

```
PROTON_FFX4_UPGRADE=1 PROTON_MLFG_UPGRADE=1 PROTON_FSR4_INDICATOR=1 %command%
```

`PROTON_FFX4_UPGRADE` makes Proton load newer component DLLs (from its own cache in `<prefix>/drive_c/windows/system32/umu/`) instead of the game's; `1` = newest in the manifest, or pin a version, e.g. `PROTON_FFX4_UPGRADE=4.1.0`. Game files stay untouched.

**Fallback — manual swap** (what the CachyOS-forum posts did, July–Aug 2026, before/without `FFX4_UPGRADE`): take `amd_fidelityfx_framegeneration_dx12.dll` and `amd_fidelityfx_upscaler_dx12.dll` from an FSR SDK release (`FidelityFX-Samples-v2.3.0-prebuilt.zip` → `Samples/Upscalers/FidelityFX_FSR/dx12/x64/Release/`, FSR 4.1.1 + frame gen 4.0.1; or SDK v2.1.0 for 4.0.3 + 4.0.0), back up the game's copies, overwrite them in the folder `find` showed, and set the Wine prefix to **Windows 11** — AMD's standalone 4.0.3+ DLLs refuse to enable ML frame gen on a prefix reporting Windows 10:

```bash
APPID=<appid>   # store URL or Properties > Updates
PROTON="$HOME/.steam/root/compatibilitytools.d/<proton folder>"
STEAM_COMPAT_DATA_PATH="$HOME/.steam/root/steamapps/compatdata/$APPID" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root" "$PROTON/proton" run winecfg
```

Windows Version → Windows 11 → OK. Undo the swap with Steam "Verify integrity of game files". The SDK zips do **not** contain `amd_fidelityfx_dx12.dll`; that file belongs to SDK 1.x games and is upgraded by path A, never by copying.

## 2C. No FSR DLLs

**OptiScaler** injects FSR 4 upscaling and ML frame gen into DLSS/XeSS/FSR2-3 games. Proton-CachyOS has it built in: `PROTON_USE_OPTISCALER=1 PROTON_MLFG_UPGRADE=1 %command%` (README calls it work-in-progress). Per-game ini tuning, and never in games with anti-cheat. Compatibility list: https://github.com/optiscaler/OptiScaler/wiki/fsr4-compatibility-list

## 3. Check

In-game enable **FSR 3.1 upscaling** and **FSR frame generation** (the game still calls them that). The watermark names the loaded versions; "Frame Generation 4.0.x" = ML frame gen active. "3.1" means the override didn't take: wrong game type / path, or (manual swap only) the prefix isn't Windows 11. First launch compiles shaders for a few minutes, once.

Proton's log for the game lists what it did: `PROTON_LOG=1 %command%`, then `grep -iE 'upscaler|fsr4|mlfg' ~/steam-<appid>.log`.

## Known problems

- Disocclusion artifacts (ghosting at moving edges, duplicated HUD reticles) — inherent to the current Redstone build, reported on Windows too.
- Rare freeze on game start; relaunch.
- Frame generation only helps when the base frame rate is already ~50+; below that it feels worse. Use it to turn a CPU-bound 60 into ~110, not a 30 into 60.
- A game update can ship a newer FSR DLL that changes which path applies; re-run the `find`.

Sources: Proton-CachyOS `protonfixes/upscalers.py` and `amdxc64.dll` (read locally, 11.0-20260703); proton-cachyos README env-var table; loathingKernel proton-upscalers manifest; Proton-EM `docs/FSR4.md`; CachyOS forum "Is FSR MLFG works via PROTON_FSR4_UPGRADE" (Jul–Aug 2026); FidelityFX SDK releases.
