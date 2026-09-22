# Step 11 — FSR 4 / Redstone ML frame generation in Proton games (AMD RDNA3/RDNA4)

## What this step is

FSR 4 **upscaling** needs nothing on RDNA4 (RX 9000) any more: pick Proton-CachyOS (11.0-20260702 or newer) or a recent Proton-GE for the game and the driver DLL is copied in automatically.

FSR **frame generation** is the part that isn't automatic. Games ship FSR 3.1's frame generation as a DLL next to their executable; AMD's Redstone ML frame generation is a newer drop-in version of the same DLL. On Windows the driver swaps it. On Linux you swap it yourself, per game, and tell Wine to report Windows 11 (the ML frame-gen DLL refuses to load otherwise). Community-confirmed on the CachyOS forum, July–August 2026; not supported by AMD, Valve or Bazzite. Expect to redo it after a game update and to re-check after a Proton update.

Only games that implement **FSR 3.1 frame generation through the DLL model** can be upgraded. If the game folder has no `amd_fidelityfx_framegeneration_dx12.dll`, this step does not apply (OptiScaler is the fallback — see the end).

## 0. Prerequisites

- An RDNA4 card (RX 9000 series) for the native path. RDNA3 (RX 7000) works with one extra variable — noted below. Older AMD cards and other vendors: not covered.
- Mesa 25.2 or newer (`glxinfo -B | grep Mesa`, or `vulkaninfo --summary`). Any current Bazzite, CachyOS or Arch qualifies.
- Proton-CachyOS or Proton-GE installed, e.g. with ProtonUp-Qt (Flathub `net.davidotek.pupgui2`), or unpack the release into `~/.steam/root/compatibilitytools.d/` and restart Steam.
- Only DX12 games. Vulkan/DX11 titles have no FSR frame-gen DLL to swap.

## 1. Get the DLLs (once)

Download from the FidelityFX SDK releases page — https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/releases

| Release | Contains | Use |
| --- | --- | --- |
| **FSR SDK v2.1.0** (`v2.1.0.zip`, FSR 4.0.3, Frame Generation 4.0.0) | The versions the forum posts confirmed working | **Start here** |
| FSR SDK v2.3.0 (`FidelityFX-Samples-v2.3.0-prebuilt.zip`, FSR 4.1.1, Frame Generation 4.0.1) | Newest signed DLLs | Try second if 2.1.0 fails or artifacts are bad; unverified in the forum thread |

The zips are large (samples + tools). Pull only the three runtime DLLs out:

```bash
mkdir -p ~/fsr4-dlls && cd ~/fsr4-dlls
unzip -l ~/Downloads/v2.1.0.zip | grep -iE 'amd_fidelityfx_(framegeneration|upscaler|)dx12\.dll' | grep -vi debug   # find them
unzip -j ~/Downloads/v2.1.0.zip '*/amd_fidelityfx_framegeneration_dx12.dll' '*/amd_fidelityfx_upscaler_dx12.dll' '*/amd_fidelityfx_dx12.dll' -d .
ls -la
```

If more than one copy of a DLL turns up (per-sample copies), they are identical builds; keep any one. If the archive holds `x64`/`x86` variants, take the 64-bit ones only.

You need these three files:

| File | Role |
| --- | --- |
| `amd_fidelityfx_framegeneration_dx12.dll` | **the frame-gen upgrade — this is the one that matters** |
| `amd_fidelityfx_upscaler_dx12.dll` | matching upscaler; swap it too so upscaler and frame gen are from the same SDK |
| `amd_fidelityfx_dx12.dll` | loader/backend shim; swap if the game ships it (some games don't have it) |

## 2. Per game: back up and replace

Find where the game keeps its FSR DLLs (usually next to the `.exe`, sometimes a plugins subfolder):

```bash
G="/path/to/steamapps/common/<Game>"                     # the game's install folder
find "$G" -iname 'amd_fidelityfx_*.dll'
```

Cyberpunk keeps them in `bin/x64/`; Unreal Engine 5 games (Expedition 33 etc.) in `<Project>/Binaries/Win64/`. Use what `find` prints, don't guess. Then:

```bash
D="$(dirname "$(find "$G" -iname 'amd_fidelityfx_framegeneration_dx12.dll' | head -1)")"
mkdir -p "$D/fsr-stock-backup" && cp -n "$D"/amd_fidelityfx_*.dll "$D/fsr-stock-backup/"
for f in amd_fidelityfx_framegeneration_dx12.dll amd_fidelityfx_upscaler_dx12.dll amd_fidelityfx_dx12.dll; do
  [ -f "$D/$f" ] && cp -v ~/fsr4-dlls/$f "$D/$f"        # only replace files the game already has
done
```

Steam's "Verify integrity of game files" will put the stock DLLs back — that is also your undo. Or copy from `fsr-stock-backup/`.

## 3. Per game: Wine prefix must say Windows 11

The ML frame-gen DLL checks the OS version and stays inactive on "Windows 10". In Steam, set the game's compatibility tool to Proton-CachyOS/GE, launch it once so the prefix exists, quit, then:

```bash
APPID=<appid>                                   # from the store URL or the game's Properties > Updates page
PROTON="$HOME/.steam/root/compatibilitytools.d/proton-cachyos"   # or the GE folder name
STEAM_COMPAT_DATA_PATH="$HOME/.steam/root/steamapps/compatdata/$APPID" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root" \
"$PROTON/proton" run winecfg
```

In the window: **Windows Version → Windows 11 → OK.** (Proton-EM 10.0-33+ and Proton-CachyOS can skip this when a native DLL is supplied; doing it anyway costs nothing.)

Heroic/Lutris: right-click the game → Wine → Run winecfg, same setting.

## 4. Launch options

Steam → game → Properties → Launch Options:

```
PROTON_FSR4_INDICATOR=1 MLFG_WATERMARK=1 %command%
```

- RDNA3 (RX 7000) only: prepend `PROTON_FSR4_RDNA3_UPGRADE=1 DXIL_SPIRV_CONFIG=wmma_rdna3_workaround`.
- `PROTON_FSR4_UPGRADE=1` is no longer needed on RDNA4 with current Proton-CachyOS; harmless if present.
- Remove the two watermark variables once you've confirmed it works.

## 5. Check

In-game: Settings → enable **FSR 3.1 upscaling** and **FSR frame generation** (the game still calls them that). With the variables above, a watermark in the top-left names the upscaler version (4.0.x / 4.1.x) and the frame-gen status. "Frame Generation 4.0.x" = Redstone ML is active. If it says 3.1, the DLL wasn't loaded: wrong folder, or the prefix isn't Windows 11.

First launch compiles shaders for a few minutes (one forum report: ~3 min). That's once per game.

## Known problems

- Disocclusion artifacts (ghosting around a moving object's edges, duplicated HUD reticles) — inherent to the current Redstone build, reported on Windows too.
- Rare freeze on game start. Relaunch.
- A game update that ships new FSR DLLs silently overwrites yours; the watermark tells you.
- Frame generation only helps when the base frame rate is already ~50+; below that it feels worse. Use it to turn a CPU-bound 60 into ~110, not a 30 into 60.

## If the game has no FSR DLLs, or the swap doesn't take

**OptiScaler** injects FSR 4 upscaling and Redstone frame gen into games that use DLSS/XeSS/older FSR, and the forum thread reports its nightly builds enabled MLFG in games where the DLL swap didn't. It is a bigger tinker (per-game ini, a DLL named as `dxgi.dll`/`winmm.dll`, anti-cheat risk in online games). Compatibility list: https://github.com/optiscaler/OptiScaler/wiki/fsr4-compatibility-list

Sources: CachyOS forum "Is FSR MLFG works via PROTON_FSR4_UPGRADE" (Jul–Aug 2026); Proton-EM `docs/FSR4.md`; GamingOnLinux on Proton-CachyOS 11.0-20260702; FidelityFX SDK releases.
