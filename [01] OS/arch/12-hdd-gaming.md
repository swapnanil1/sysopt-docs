# HDD gaming tweaks (mechanical drives only)

`cachyos-settings` already gives every rotational disk `bfq`. This overrides it per disk. Names from `lsblk -d -o NAME,ROTA,MODEL` (they can shift if you add disks — re-check after hardware changes).

`/etc/udev/rules.d/99-hdd-tweaks.rules` — scheduler line first, its `iosched/*` attrs only exist after the switch:

```
# OS + /home HDD: bfq keeps background writes from starving reads; 2 MB read-ahead
ACTION=="add|change", KERNEL=="sda", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sda", ATTR{queue/read_ahead_kb}="2048"

# Pure games HDD — SAFE: bfq without fairness idling, 4 MB read-ahead
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/iosched/low_latency}="0"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/iosched/slice_idle}="0"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/read_ahead_kb}="4096"

# Pure games HDD — FAST: mq-deadline (reads first, no idling at all), 6 MB read-ahead for big .pak streaming
# ACTION=="add|change", KERNEL=="sdb", ATTR{queue/scheduler}="mq-deadline"
# ACTION=="add|change", KERNEL=="sdb", ATTR{queue/read_ahead_kb}="6144"
```

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger --action=change /dev/sda /dev/sdb
cat /sys/block/sd[ab]/queue/scheduler /sys/block/sd[ab]/queue/read_ahead_kb
```

Left out on purpose (already the defaults): `nr_requests=128`, mq-deadline `front_merges=1`, `read_expire=500`.

Defragment the games disk after big Steam installs (parallel chunk downloads scatter `.pak` files; ext4 only, never on SSD):

```bash
sudo e4defrag -c /mnt/Games      # fragmentation score; worth running the next line above ~30
sudo e4defrag /mnt/Games         # game closed; takes a while on a full disk
```

Stutter during huge asset loads on the CachyOS kernel (THP `always` + shrinker) → try `madvise`:

```bash
echo 'w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise' | sudo tee /etc/tmpfiles.d/thp-madvise.conf
sudo systemd-tmpfiles --create
```

fstab and sysctl for HDDs are in [01-fstab](./01-fstab.md) (FAST lines) and [08-sysctl](./08-sysctl.md) (`99-vm-hdd.conf`). `commit=300`, `vm.swappiness=30` and shader caches on `/tmp`: not worth it — [notes §12](./99-notes.md#12-hdd-gaming).
