# Step 6 — Performance settings that Bazzite already has, and two you can add

## What this step is

Most of the performance tuning from the Arch guide is **already built into Bazzite**. This step lists it so you don't redo it, then adds two optional things Bazzite leaves switched off, and explains the one habit that replaces `gamemode`.

## Already done for you (do not add these again)

- `vm.max_map_count` (huge, for games) and zram compressed swap.
- **Not done, despite what older notes say:** the memory/swap *policy*. On image 44.20260919 Bazzite's tuned profiles contain no memory settings of their own, so Performance mode inherits the server-oriented `vm.swappiness=10` and a 40 % dirty-memory limit. With zram that is backwards and causes stutter under memory pressure. [Step 8](./08-sysctl-udev.md) fixes it — do not skip it.
- Disk request scheduling per drive type (HDD → `bfq`, SSD/NVMe → `kyber`) via udev rules.
- Network: BBR congestion control, MTU probing.
- `ntsync` for Wine/Proton, and a "foreground app gets priority" booster for KDE. (A network auto-tuner, `bpftune`, is installed but its service is disabled on this image.)
- **gamemode is deliberately removed** from Bazzite and is not supported. If a game's launch options contain `gamemoderun %command%`, delete that word. There is no `ananicy` either.

## The Balanced / Performance switch is your "game mode"

Click the battery/power icon in the KDE tray → choose **Performance** before a heavy game, **Balanced** afterwards. On Bazzite this switch does more than on other distros: it changes the CPU governor and boost, memory tuning, and (after the next section) the CPU scheduler mode. From the terminal the same thing is:

```bash
powerprofilesctl set performance
powerprofilesctl set balanced
```

## Optional A — bpfland, a desktop/game-oriented CPU scheduler

Bazzite's kernel supports "sched-ext": CPU schedulers you can load and unload while the system runs. **bpfland** gives whatever you are interacting with (the game, the window you click) priority over background work. Bazzite installs it but leaves it off on desktops. Turning it on is a small config file in `/etc` (survives updates) plus enabling a service:

```bash
sudo install -Dm644 /dev/stdin /etc/scx_loader/config.toml <<'EOF'
default_sched = "scx_bpfland"
default_mode = "Auto"
EOF
sudo systemctl enable --now scx_loader.service
scxctl get                                  # → running Bpfland in … mode
cat /sys/kernel/sched_ext/root/ops          # → bpfland_…  (run it a few seconds later; right after a restart it can still say nothing)
```

No per-mode flags are needed — the loader has built-in ones for bpfland. From now on the Performance/Balanced switch above also flips the scheduler between "gaming" and "auto" — Bazzite wires that up itself. To try a scheduler without touching the file: `scxctl switch -s bpfland -m gaming` (no sudo).

> **Do not use `scx_lavd` on this kernel.** Tested 2026-09-22 (scx 1.1.3, kernel 7.2.4-ogc, Ryzen 5 3600): with a game loading plus a browser, LAVD left tasks unscheduled for 30–45 s at a time — KWin's compositor, `wineserver`, the game's own threads. It looks like the whole machine crashing. The kernel watchdog ejects it, the loader starts it again, and it stalls again. LAVD also logged ~100 "deprecated interface" kernel warnings; bpfland logged none and ran the same load without a stall.

Check for stalls after a gaming session — this must print nothing:

```bash
journalctl -k -b --no-pager | grep -E "runnable task stall|failed to run for"
```

If it prints anything, or anything feels worse (stutter, audio crackle), go back to the kernel's own scheduler:

```bash
sudo systemctl disable --now scx_loader.service
```

## Optional B — switch off the hardware watchdog

A watchdog is a timer that reboots the machine if the kernel hangs completely. Desktops don't need it and it costs a little. Bazzite has a recipe that sets the `nowatchdog` kernel argument and blacklists the watchdog drivers; it asks a yes/no question:

```bash
ujust configure-watchdog
```

(Takes effect after a reboot — combine with Step 7.)

Background: [notes §6](./99-notes.md#6-performance).
