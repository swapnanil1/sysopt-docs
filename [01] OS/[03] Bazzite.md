# Bazzite (KDE) — performance tweaks that survive updates

Command-first, same shape as the [Arch guide](./[01]%20ArchAIO.md). Background and sources: [`bazzite/99-notes.md`](./bazzite/99-notes.md). Verified against the `bazzite:stable` image and its docs source, August 2026 (Fedora 44 base, OGC kernel 7.2).

**Start point:** `bazzite` (KDE desktop image, AMD GPU) installed from the ISO with the default btrfs layout (`root`/`home`/`var` subvolumes, `compress=zstd:1`), root on a HDD, a second HDD for games.

**What persists across image updates — put every tweak here, nowhere else:**

| Persists | Doesn't |
|---|---|
| `/etc/**` (3-way merged; a file you modified is kept forever) — `fstab`, `sysctl.d`, `udev/rules.d`, `tuned/profiles`, `systemd/system`, `scx_loader`, `modprobe.d` | anything under `/usr` (read-only, replaced every update) |
| `/var/**` — `/var/home`, `/var/mnt` (`/mnt` is a symlink to it), `/var/usrlocal`, `/var/opt` | `/boot/loader/entries/*` edits (ostree rewrites them; use `rpm-ostree kargs`) |
| `rpm-ostree kargs`, `rpm-ostree install` layers, Flatpaks, Homebrew, removed Flatpaks (they are not reinstalled) | the kernel — it is version-locked in the image and cannot be swapped |

Check what you've changed under `/etc` any time: `sudo ostree admin config-diff`.

| Step | File |
|---|---|
| 1 | [fstab](./bazzite/01-fstab.md) — root subvolumes on a HDD, games HDD under `/var/mnt` |
| 2 | [Debloat](./bazzite/02-debloat.md) — Flatpaks, autostarts; what not to remove |
| 3 | [Hardware](./bazzite/03-hardware.md) — LACT, CoolerControl, OverDrive karg |
| 4 | [Shell & CLI](./bazzite/04-shell-cli.md) — fish (in the image), Homebrew tools |
| 5 | [Performance](./bazzite/05-performance.md) — what the image already tunes, sched-ext LAVD, power profiles |
| 6 | [Kernel args](./bazzite/06-kargs.md) — SAFE / MAX via `rpm-ostree kargs` |
| 7 | [sysctl, tuned & HDD udev](./bazzite/07-sysctl-udev.md) — HDD tuning that tuned won't overwrite |
| 8 | [Rollback & backup](./bazzite/08-rollback.md) — pin the deployment, home backup |
| 9 | [Apps](./bazzite/09-apps.md) — Flatpak / brew / layering, Steam launch options |
| + | [Notes & reference](./bazzite/99-notes.md) |

Flow: `1 → 2 → 3 → 4 → 5 → 6 → 7 → reboot → 8 pin → 9 apps`. Kargs and layered packages only take effect after a reboot; batch them.
