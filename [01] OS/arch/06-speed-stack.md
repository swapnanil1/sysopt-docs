# 6 — CachyOS speed stack

```bash
sudo pacman -S --needed cachyos-settings power-profiles-daemon python-gobject   # pulls zram-generator, ananicy-cpp, cachyos-ananicy-rules
sudo systemctl enable --now ananicy-cpp.service power-profiles-daemon.service systemd-resolved.service systemd-timesyncd.service
# point applications at the resolver only after its service is running
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# optional, decoration only: sudo pacman -S cachyos-hello
```

What `cachyos-settings` gives you for free (don't duplicate): zram swap (`zram-size = ram`, zstd), `vm.swappiness=150` via udev, I/O schedulers (HDD bfq / SSD mq-deadline / NVMe kyber), SATA `max_performance`, `hdparm -B 254 -S 0` on HDDs (needs `hdparm`), watchdog blacklist, ntsync autoload, THP shrinker, 10 s service stop timeout (system **and** user — it kills `psd unsync` on HDD boxes; per-unit override in step 3), 50 MB journal, NOFILE limits, NM → systemd-resolved, `@audio` rtprio, and the **`game-performance`** wrapper (`game-performance %command%` in Steam = performance power profile for the game's lifetime). Full table: [notes §6](./99-notes.md#6-speed-stack).

Continue to [step 7 — kernel setup](./07-kernel.md). The reboot during kernel setup activates zram. **16 GB RAM or less, with memory-heavy workloads:** [step 10](./10-ssd-swap.md) adds optional SSD swap after that reboot, starting from an existing `@swap` Btrfs subvolume mounted at `/swap`.

Do **not** install: `cachyos-hooks` (rebrands `/etc/os-release`), `chwd`, `cachyos-kernel-manager`, any `*-meta`, `gamemode` (conflicts with ananicy-cpp).
