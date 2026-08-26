# Step 8 — Memory tuning for hard drives (tuned), network, and per-disk rules (udev)

## What this step is

Three small things, all in `/etc` (so they survive updates):

1. **Memory/write tuning for HDDs.** The kernel keeps written data in RAM for a while before putting it on the disk. Bazzite's defaults are sized for SSDs; on a spinning drive they let too much pile up, and when it finally flushes the whole desktop stutters for seconds. We lower those limits. On Bazzite these values are managed by a service called **tuned**, which re-applies its own numbers every time you switch Balanced/Performance — so putting ours in the usual `sysctl` file would get overwritten. Instead we give tuned two tiny profiles of our own that *extend* Bazzite's. Then tuned applies our numbers.
2. **A few network settings** tuned doesn't manage — these go into a normal sysctl file.
3. **udev rules** — how the kernel queues requests for each disk, plus how far ahead it reads. Bazzite already sets a sensible default for HDDs; we tune the games disk specifically.

## 1. HDD memory tuning via tuned

Paste the whole block into the terminal as one piece:

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
```

What that did: created `balanced-hdd` (= Bazzite's Balanced profile + our five numbers) and `performance-hdd` (= Bazzite's Performance profile + the same five), and told the power-profile switch to use ours. The numbers: start writing to disk in the background at 32 MB of pending data, force programs to wait at 128 MB (instead of hundreds of MB), and keep file-name/folder information in memory (`vfs_cache_pressure=20`) so the disk head doesn't have to seek for it.

Check:

```bash
tuned-adm active                                                 # → Current active profile: balanced-hdd
sysctl vm.dirty_bytes vm.vfs_cache_pressure vm.swappiness        # → 134217728, 20, 180
```

`swappiness` stays at Bazzite's 180 on purpose — with compressed-RAM swap (zram) a high value is correct.

## 2. Network settings

```bash
sudo tee /etc/sysctl.d/99-network.conf >/dev/null <<'EOF'
net.core.default_qdisc = cake
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF
sudo sysctl --system      # apply now; prints every file it read
```

(`cake` = a fairer packet queue; the other two shave latency on bursty game traffic. BBR is already on.) For the "magic SysRq" emergency keys (REISUB), Bazzite has `ujust reisub`.

## 3. Per-disk rules (udev)

First find which disk is which:

```bash
lsblk -d -o NAME,ROTA,SIZE,MODEL      # sda / sdb …; ROTA 1 = HDD
```

Below, `sda` is the system+home HDD and `sdb` the games HDD — swap the names if yours differ. Create the file:

```bash
sudoedit /etc/udev/rules.d/99-hdd-tweaks.rules
```

Paste (the scheduler line of each disk must come before its other lines):

```
# system + /home HDD: bfq (keeps background writes from starving reads), 2 MB read-ahead
ACTION=="add|change", KERNEL=="sda", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sda", ATTR{queue/read_ahead_kb}="2048"

# games HDD — SAFE: bfq without its fairness idling, 4 MB read-ahead
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/iosched/low_latency}="0"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/iosched/slice_idle}="0"
ACTION=="add|change", KERNEL=="sdb", ATTR{queue/read_ahead_kb}="4096"

# games HDD — FAST: mq-deadline (reads first, no idling), 6 MB read-ahead. To use it, delete the four SAFE lines above and remove the leading "# " here:
# ACTION=="add|change", KERNEL=="sdb", ATTR{queue/scheduler}="mq-deadline"
# ACTION=="add|change", KERNEL=="sdb", ATTR{queue/read_ahead_kb}="6144"
```

Optional, games disk never spins down (more responsive, a little more power/noise): add one more line

```
ACTION=="add|change", KERNEL=="sdb", RUN+="/usr/sbin/hdparm -B 254 -S 0 /dev/%k"
```

Save, then apply and check:

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger --action=change /dev/sda /dev/sdb
cat /sys/block/sd[ab]/queue/scheduler          # the active one is in [brackets]
cat /sys/block/sd[ab]/queue/read_ahead_kb      # 2048 and 4096 (or 6144)
```

## Maintenance tip for the games HDD

Steam downloads many pieces of a game in parallel, which scatters the files on a spinning disk. After installing a big game:

```bash
sudo e4defrag -c /var/mnt/Games     # only reports a "fragmentation score"
sudo e4defrag /var/mnt/Games        # defragments; run with the game closed, it takes a while
```

Background: [notes §8](./99-notes.md#8-sysctl-tuned-udev).
