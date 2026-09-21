# Step 8 — Memory tuning (tuned), network, and per-disk rules (udev)

## What this step is

Three small things, all in `/etc` (so they survive updates):

1. **Memory and swap policy — needed on every install, SSD or HDD.** Bazzite swaps into compressed RAM (zram), which is nearly free, but on image 44.20260919 nothing tells the kernel to *use* it: Performance mode inherits `vm.swappiness=10` from a server profile, so under memory pressure the kernel throws away file cache instead and everything has to be re-read from disk — stutter, or multi-second freezes with games on a hard drive. It also lets up to 40 % of RAM fill with unwritten data before flushing. We set the same values CachyOS ships. On Bazzite these values are managed by a service called **tuned**, which re-applies its own numbers every time you switch Balanced/Performance — so putting ours in the usual `sysctl` file would get overwritten. Instead we give tuned two tiny profiles of our own that *extend* Bazzite's. Then tuned applies our numbers.
2. **A few network settings** tuned doesn't manage — these go into a normal sysctl file.
3. **udev rules** — how the kernel queues requests for each disk, plus how far ahead it reads. Bazzite already sets a sensible default for HDDs; we tune the games disk specifically.

## 1. Memory and swap policy via tuned

Check what you have first — if this prints `10` or `60`, you need this section:

```bash
sysctl vm.swappiness
```

Paste the whole block into the terminal as one piece:

```bash
sudo mkdir -p /etc/tuned/profiles/{balanced-zram,performance-zram}
sudo tee /etc/tuned/profiles/balanced-zram/tuned.conf >/dev/null <<'EOF'
[main]
include=balanced-bazzite
[sysctl]
vm.swappiness=150
vm.page-cluster=0
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
vm.compaction_proactiveness=0
vm.vfs_cache_pressure=50
vm.dirty_bytes=268435456
vm.dirty_background_bytes=67108864
vm.dirty_writeback_centisecs=1500
EOF
sudo sed 's/include=balanced-bazzite/include=throughput-performance-bazzite/' /etc/tuned/profiles/balanced-zram/tuned.conf | sudo tee /etc/tuned/profiles/performance-zram/tuned.conf >/dev/null
sudo sed -i '/^\[profiles\]/,/^\[battery\]/ { s/^balanced=.*/balanced=balanced-zram/; s/^performance=.*/performance=performance-zram/ }' /etc/tuned/ppd.conf
sudo systemctl restart tuned tuned-ppd
```

What that did: created `balanced-zram` (= Bazzite's Balanced profile + our numbers) and `performance-zram` (= Bazzite's Performance profile + the same numbers), and told the power-profile switch to use ours. The `sed` only touches the `[profiles]` section of `ppd.conf`; the `[battery]` section has its own `balanced=` line that must keep pointing at the battery profile.

The numbers: `swappiness=150` = prefer compressing idle memory over dropping file cache; `page-cluster=0` = read one page at a time from swap (read-ahead is for disks, not RAM); the two `watermark` values = start reclaiming memory early and gently instead of late and in bursts; `compaction_proactiveness=0` = no background memory defragmentation; `vfs_cache_pressure=50` = keep file-name/folder information in memory longer; `dirty_*` = start writing to disk in the background at 64 MB of pending data and make programs wait at 256 MB.

**HDD root only** — if the *system* itself is on a spinning drive, use tighter write limits so a flush can't stall the desktop. In the block above replace the three `dirty`/`vfs` lines with:

```
vm.vfs_cache_pressure=20
vm.dirty_bytes=134217728
vm.dirty_background_bytes=33554432
vm.dirty_writeback_centisecs=1500
vm.dirty_expire_centisecs=3000
```

(An SSD root with games on HDDs keeps the main values — 256 MB is already small enough.)

Check:

```bash
tuned-adm active                                                 # → Current active profile: balanced-zram (or performance-zram)
sysctl vm.swappiness vm.page-cluster vm.dirty_bytes              # → 150, 0, 268435456
```

Restarting `tuned-ppd` drops you back to the default power mode (Balanced); pick Performance again from the tray if you were in it. To boot straight into Performance every time: `sudo sed -i 's/^default=.*/default=performance/' /etc/tuned/ppd.conf`.

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
