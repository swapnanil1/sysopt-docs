# 8 — sysctl

Already set — don't duplicate: `vm.max_map_count=1048576` (Arch; **never set 262144, it lowers it**), cachyos-settings' `70-cachyos-settings.conf`, `vm.swappiness=150` (zram udev rule — sysctl.d cannot override it), `kernel.split_lock_mitigate=0`, `vm.compaction_proactiveness=0`. `kernel.sched_*` knobs no longer exist. Use `dirty_*_bytes` **or** `dirty_*_ratio`, never both.

`/etc/sysctl.d/99-vm-hdd.conf` (HDD root):

```
vm.dirty_background_bytes = 33554432
vm.dirty_bytes = 134217728
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
vm.vfs_cache_pressure = 20
vm.watermark_scale_factor = 125
vm.watermark_boost_factor = 0
vm.compaction_proactiveness = 0
vm.page-cluster = 0
```

`/etc/sysctl.d/99-vm-ssd.conf` (SSD root — cachyos dirty defaults are fine):

```
vm.watermark_scale_factor = 125
vm.watermark_boost_factor = 0
vm.compaction_proactiveness = 0
vm.page-cluster = 0
```

`/etc/sysctl.d/99-network.conf` (optional):

```
net.ipv4.tcp_congestion_control = bbr3      # stock Arch kernel: bbr
net.core.default_qdisc = cake
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 16384
```

`/etc/sysctl.d/99-misc.conf`:

```
kernel.sysrq = 244
```

```bash
sudo sysctl --system && sysctl vm.swappiness vm.dirty_bytes net.ipv4.tcp_congestion_control
```

CPU: leave ppd on *balanced* + `game-performance` (SAFE). MAX = pin performance:

```bash
sudo tee /etc/systemd/system/ppd-performance.service >/dev/null <<'EOF'
[Unit]
Description=Pin power-profiles-daemon to performance
After=power-profiles-daemon.service
Requires=power-profiles-daemon.service
[Service]
Type=oneshot
ExecStart=/usr/bin/powerprofilesctl set performance
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now ppd-performance.service
```

Knob reference: [notes §8](./99-notes.md#8-sysctl).
