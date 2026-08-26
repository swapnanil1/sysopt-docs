# Step 6 — Performance settings that Bazzite already has, and two you can add

## What this step is

Most of the performance tuning from the Arch guide is **already built into Bazzite**. This step lists it so you don't redo it, then adds two optional things Bazzite leaves switched off, and explains the one habit that replaces `gamemode`.

## Already done for you (do not add these again)

- Memory and swap tuning (`vm.max_map_count`, `swappiness=180` with zram compressed swap, dirty-memory limits) — applied by a service called **tuned**.
- Disk request scheduling per drive type (HDD → `bfq`, SSD/NVMe → `kyber`) via udev rules.
- Network: BBR congestion control, MTU probing.
- `ntsync` for Wine/Proton, a "foreground app gets priority" booster for KDE, and a network auto-tuner.
- **gamemode is deliberately removed** from Bazzite and is not supported. If a game's launch options contain `gamemoderun %command%`, delete that word. There is no `ananicy` either.

## The Balanced / Performance switch is your "game mode"

Click the battery/power icon in the KDE tray → choose **Performance** before a heavy game, **Balanced** afterwards. On Bazzite this switch does more than on other distros: it changes the CPU governor and boost, memory tuning, and (after the next section) the CPU scheduler mode. From the terminal the same thing is:

```bash
powerprofilesctl set performance
powerprofilesctl set balanced
```

## Optional A — LAVD, a game-oriented CPU scheduler

Bazzite's kernel supports "sched-ext": CPU schedulers you can load and unload while the system runs. **LAVD** is the one written with games in mind. Bazzite installs it but leaves it off on desktops. Turning it on is a small config file in `/etc` (survives updates) plus enabling a service:

```bash
sudo install -Dm644 /dev/stdin /etc/scx_loader/config.toml <<'EOF'
default_sched = "scx_lavd"
default_mode = "Auto"

[scheds.scx_lavd]
auto_mode = []
gaming_mode = ["--performance"]
lowlatency_mode = ["--performance"]
powersave_mode = ["--powersave"]
EOF
sudo systemctl enable --now scx_loader.service
scxctl get                       # should show scx_lavd and the current mode
```

From now on the Performance/Balanced switch above also flips LAVD between "gaming" and "auto" — Bazzite wires that up itself. If anything feels worse (stutter, audio crackle), turn it off again:

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
