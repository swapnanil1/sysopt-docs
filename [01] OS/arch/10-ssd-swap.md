# 10 — Optional SSD swap alongside zram

**For systems with 16 GB RAM or less:** follow this if memory-heavy applications exhaust RAM and zram, cause freezes, or get killed. It adds a **16 GiB SSD swapfile** while keeping zram enabled. Systems with more RAM can use it too if their workloads need it; swap capacity is not a substitute for RAM.

**When:** after [step 9 — sysctl](./09-sysctl.md). The kernel reboot in step 7 or 8 should already have activated zram from [step 6](./06-speed-stack.md). Finish this setup before the [step 13 checks and baseline snapshot](./13-timeshift.md). On an existing desktop with zram active, you can do it at any time with memory-heavy applications closed.

**Starting point:** a single-device Btrfs filesystem on an SSD, with a separate `@swap` subvolume already created and persistently mounted at `/swap`. `@swap` is a **subvolume, not a partition**. It shares the filesystem's free space; the command below allocates the 16 GiB file inside it. If you created an actual Linux swap partition instead, this file-based guide does not apply.

## 1. Check the existing setup

```bash
free -h
swapon --show
findmnt --mountpoint /swap --output TARGET,SOURCE,FSTYPE,OPTIONS
findmnt --fstab --mountpoint /swap --output TARGET,SOURCE,FSTYPE,OPTIONS
lsblk -o NAME,TYPE,SIZE,FSTYPE,ROTA,MOUNTPOINTS
```

Before continuing, check:

- `swapon` lists `/dev/zram0` with priority **100** from step 6. If missing, finish step 6 and reboot first. If you customized its priority, it must be higher than the SSD swap's **10**.
- Both `findmnt` commands show `/swap`, filesystem `btrfs`, and `subvol=/@swap` or `subvol=@swap`. The live mount must be writable (`rw`). No output means the mount or its `/etc/fstab` entry is missing: fix that through [step 1](./01-fstab.md) first.
- The backing drive has `ROTA=0` (non-rotating storage). This guide assumes an SSD.

Check the filesystem layout and available space:

```bash
sudo btrfs filesystem show /swap
sudo btrfs filesystem usage /swap
btrfs version
```

Expect **one device**, **Data,single**, and comfortably more than **16 GiB free**, leaving room for updates and snapshots. `Metadata,DUP` is fine. Use `btrfs-progs` **6.1 or newer** for the creation command below. These checks cover the simple layout used here; see the [Btrfs swapfile requirements](https://btrfs.readthedocs.io/en/latest/Swapfile.html) for other layouts.

## 2. Create and enable the 16 GiB file

Run this once, after the checks above. The first command ensures `/swap` is mounted before creating anything; `&&` stops the sequence if a command fails.

```bash
mountpoint -q /swap && \
sudo btrfs filesystem mkswapfile --size 16G /swap/swapfile && \
sudo chmod 600 /swap/swapfile && \
sudo btrfs inspect-internal map-swapfile /swap/swapfile && \
sudo swapon --priority 10 /swap/swapfile
```

The [Btrfs helper](https://btrfs.readthedocs.io/en/latest/btrfs-filesystem.html) allocates and formats the file with the required no-copy-on-write properties. No separate `mkswap`, global `nodatacow` mount option, or change to root compression is needed. `map-swapfile` checks that the file is suitable; its printed offsets are not needed here.

If any command reports an error, stop before editing `/etc/fstab`. If the file already exists, check `swapon --show` and inspect the existing setup rather than overwriting it. For an activation error, inspect:

```bash
sudo journalctl -k -b --grep='swap|btrfs' --case-sensitive=no -n 40
```

Verify activation:

```bash
swapon --show --output NAME,TYPE,SIZE,USED,PRIO
```

Expected entries (zram size depends on installed RAM):

| Name | Size | Priority |
|---|---|---|
| `/dev/zram0` | Set by step 6 | 100 |
| `/swap/swapfile` | About 16 GiB | 10 |

Higher-priority swap is used first, so zram stays preferred and the SSD supplies additional capacity. Adding the SSD does not automatically move pages already in zram onto disk. [Linux swap priorities](https://man7.org/linux/man-pages/man2/swapon.2.html).

## 3. Enable it on every boot

Back up and edit `/etc/fstab`:

```bash
sudo cp --backup=numbered /etc/fstab /etc/fstab.before-ssd-swap
sudoedit /etc/fstab
```

Keep the existing Btrfs mount entry for `/swap`. Add this **separate line once**, or update it if `/swap/swapfile` is already listed:

```fstab
/swap/swapfile  none  swap  defaults,pri=10,nofail  0 0
```

Use the file path, not the UUID printed when the swapfile was created. `nofail` lets boot continue if this optional swapfile cannot activate. Systemd orders file-backed swap after the filesystem mount automatically. [systemd swap configuration](https://www.freedesktop.org/software/systemd/man/latest/systemd.swap.html).

Reload the configuration, then validate before rebooting:

```bash
sudo systemctl daemon-reload
sudo findmnt --verify --verbose
```

Fix any reported errors first. A warning that `/swap/swapfile` is a regular file is expected for this file-backed swap, provided its type is `swap` and activation succeeds. Then check activation:

```bash
sudo swapon --all
swapon --show --output NAME,TYPE,SIZE,USED,PRIO
```

The swapfile is active now. In the numbered setup sequence, continue to step 11; [step 13](./13-timeshift.md) includes a reboot and persistence check before the snapshot. On an existing desktop, reboot when convenient and run the same `swapon --show` command: **both entries and their priorities must still appear**.

## 4. Keep snapshots and memory tuning consistent

Keep `@swap` outside your snapshot set. Root snapshots of `@` do not include the separately mounted `@swap` contents. An active swapfile prevents snapshots of its own subvolume; putting it directly in `@` would interfere with root snapshots. Separate subvolumes do not remove filesystem-wide restrictions: active swapfiles also affect balance and scrub. See [Btrfs maintenance restrictions](https://btrfs.readthedocs.io/en/latest/Swapfile.html) before those operations.

Keep the zram size, swappiness, and out-of-memory protection from the existing guide initially. Do not run `swapoff -a` to apply this setup: disabling swap under memory pressure can exhaust RAM.

During a representative workload, check:

```bash
free -h
swapon --show
zramctl
vmstat 1 10
```

Zram's advertised size is logical capacity; its compressed contents still occupy physical RAM. SSD swap provides extra room for pageable memory, but heavy disk swapping can slow applications, and memory exhaustion can still occur before all swap is used. Persistent pressure calls for reducing the workload or adding RAM. This guide configures paging only; hibernation needs separate resume configuration.
