# 8 — sysctl, tuned & HDD udev

**What this does.** `sysctl` values are kernel tunables (how much data to keep in RAM before writing, how aggressively to use swap…). On Bazzite a service called **tuned** re-applies its own set of these every time the power profile changes, so anything you put in a plain sysctl file gets overwritten seconds later. The fix is to give tuned a small profile of your own that extends Bazzite's — then *tuned* applies your HDD values. The udev rule at the end tells the kernel how to queue disk requests per drive; that part is not managed by tuned and lives in `/etc` normally.

**tuned rewrites `vm.swappiness`/`vm.dirty_*`/watermarks every time a power profile activates (after `systemd-sysctl` ran), so HDD memory tuning goes into a tuned profile, not `/etc/sysctl.d`.** Profiles under `/etc/tuned/profiles/` persist and extend the image's.

```bash
sudo mkdir -p /etc/tuned/profiles/{balanced-hdd,performance-hdd}
sudo tee /etc/tuned/profiles/balanced-hdd/tuned.conf >/dev/null <<'EOF'
[main]
include=balanced-bazzite
[sysctl]
vm.dirty_background_bytes=33554432
vm.dirty_bytes=134217728
vm.dirty_writeback_centisecs=1500
vm.dirty_expire_centisecs=3000
vm.vfs_cache_pressure=20
EOF
sudo sed 's/include=balanced-bazzite/include=throughput-performance-bazzite/' /etc/tuned/profiles/balanced-hdd/tuned.conf | sudo tee /etc/tuned/profiles/performance-hdd/tuned.conf >/dev/null
sudo sed -i 's/^balanced=.*/balanced=balanced-hdd/; s/^performance=.*/performance=performance-hdd/' /etc/tuned/ppd.conf
sudo systemctl restart tuned tuned-ppd
tuned-adm active && sysctl vm.dirty_bytes vm.vfs_cache_pressure vm.swappiness   # 134217728 / 20 / 180
```

(swappiness 180 is right with zram — leave it. Older tuned: `/etc/tuned/<name>/tuned.conf` instead of `/etc/tuned/profiles/<name>/`.)

Keys tuned doesn't touch — `/etc/sysctl.d/99-network.conf` (BBR is already on):

```
net.core.default_qdisc = cake
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
```

`sudo sysctl --system`. Magic SysRq for REISUB: `ujust reisub`.

## HDD udev rule (persists; overrides the image's bfq-for-HDD rule per disk)

`/etc/udev/rules.d/99-hdd-tweaks.rules` — scheduler line first:

```
# OS + /home HDD
ACTION=="add|change", KERNEL=="sda", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sda", ATTR{queue/read_ahead_kb}="2048"
# games HDD — SAFE
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/iosched/low_latency}="0"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/iosched/slice_idle}="0"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/read_ahead_kb}="4096"
# games HDD — FAST
# ACTION=="add|change", KERNEL=="sdb", ATTR{queue/scheduler}="mq-deadline"
# ACTION=="add|change", KERNEL=="sdb", ATTR{queue/read_ahead_kb}="6144"
```

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger --action=change /dev/sda /dev/sdb
cat /sys/block/sd[ab]/queue/scheduler /sys/block/sd[ab]/queue/read_ahead_kb
```

No hdparm rule in the image: for no-spindown on the games disk add `ACTION=="add|change", KERNEL=="sdb", RUN+="/usr/sbin/hdparm -B 254 -S 0 /dev/%k"` (hdparm is in the image). After big Steam installs on the HDD: `sudo e4defrag -c /var/mnt/Games` then `sudo e4defrag /var/mnt/Games`. [notes §7](./99-notes.md#8-sysctl-tuned-udev).
