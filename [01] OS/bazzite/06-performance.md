# 6 — Performance

Already in the image (don't duplicate): `vm.max_map_count=2147483642`, `kernel.split_lock_mitigate=0`, BBR + `tcp_mtu_probing`, inotify limits; via **tuned** profiles `balanced-bazzite`/`throughput-performance-bazzite`: `vm.swappiness=180`, `watermark_boost_factor=0`, `watermark_scale_factor=125`, `dirty_bytes=256M`/`dirty_background_bytes=128M`, `page-cluster=0`, AMD boost on; udev I/O schedulers (HDD bfq, SSD/NVMe kyber); zram zstd `min(ram/2, 16G)`; ntsync; foreground-app cgroup boost (`dmemcg-booster`); bpftune network tuner. **gamemode is removed and unsupported** — drop `gamemoderun` from launch options; there is no ananicy.

## Power profile = the game-performance switch

KDE's battery/power applet → *Performance* maps to `throughput-performance-bazzite` (governor performance, boost on, and — if enabled below — LAVD in gaming mode). CLI: `powerprofilesctl set performance` (tuned-ppd). No wrapper script needed.

## sched-ext LAVD (optional; off by default on desktop, config persists in `/etc`)

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
scxctl get                       # current scheduler / mode
# undo: sudo systemctl disable --now scx_loader.service
```

Bazzite's tuned scripts then switch LAVD to gaming mode on *Performance* and back to auto on *Balanced*.

## Watchdog off (Bazzite's own recipe; sets `nowatchdog` + blacklists the TCO modules)

```bash
ujust configure-watchdog
```

[notes §5](./99-notes.md#6-performance).
