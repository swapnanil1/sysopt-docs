# Bazzite (KDE) — performance tweaks that survive updates

Command-first, same shape as the [Arch guide](./[01]%20ArchAIO.md), with a short 'what this does and why' at the top of each step. Background and sources: [`bazzite/99-notes.md`](./bazzite/99-notes.md). Verified against the `bazzite:stable` image and its docs source, August 2026 (Fedora 44 base, OGC kernel 7.2).

**Start point:** `bazzite` (KDE desktop image, AMD GPU; rebased to `bazzite-dx` in step 2) installed from the ISO with **manual partitioning, ext4 everywhere** because the drives are HDDs: `/boot/efi` (EFI, 1 GiB), `/boot` (ext4, 1 GiB), `/` (ext4), `/var/home` (ext4, rest), plus a second ext4 HDD for games. Bazzite's docs say only btrfs is supported for `/` — ext4 installs and boots fine (ostree does not need btrfs), but `ujust configure-snapshots` (snapper), bees dedup and the btrfs SD-card tooling stop applying. On an SSD, keep the installer's btrfs default and see the btrfs lines in the notes.

## How Bazzite works, in plain language

- **The OS is one read-only image.** Think phone firmware: `/usr` (every program Bazzite ships, the kernel, drivers) is a single snapshot you cannot edit, and an update is a *whole new snapshot*, not a pile of package changes. That is "immutable". It is not locked any further than that — your files, your settings and anything you install the Bazzite way are ordinary writable files.
- **Deployment** = one bootable copy of that image on your disk. After an update you have two: the new one and the one you were just running. GRUB lists them as **`ostree:0`** (newest, boots by default) and **`ostree:1`** (the previous one). By default only these two are kept; the older one is deleted when the next update arrives.
- **Rollback** = booting `ostree:1` instead of `ostree:0`. `rpm-ostree rollback` makes the previous one the default again. Both deployments share the same `/etc`, `/var` and `/home`, so rolling back changes *only the OS image* — your documents, games and edited config files stay exactly as they are (good and bad: a broken `/etc/fstab` follows you).
- **Pinning** (`ostree admin pin`) = "never delete this deployment". Without it, two updates later your known-good OS is gone. Pin the one you finished tuning; you can then always boot back to it.
- **Rebase** = switch to a different image (e.g. `bazzite` → `bazzite-dx`). Mechanically it is just an update whose source changed; everything you own carries over.
- **Where your changes live** — the only places that survive an update: `/etc` (configuration; the update merges its new defaults with your edits and your edited files always win), `/var` (which contains `/home`, `/var/mnt`, brew, Flatpaks), **kernel arguments** stored per deployment (`rpm-ostree kargs`), and **layered packages**.
- **Layering** (`rpm-ostree install pkg`) = an RPM stacked on top of the image and re-applied to every future update. It works, but each layer makes updates slower and can block them, so the guide uses it only when Flatpak and brew can't do the job.
- **Flatpak** = sandboxed desktop apps installed under `/var`; **Homebrew** = command-line tools installed under `/home/linuxbrew`. Both are outside the image, so both survive updates — that is why they are Bazzite's preferred way to add software.
- **Kernel arguments (kargs)** = options the kernel reads at boot (`mitigations=off`, `amd_iommu=off`, …). They are stored with each deployment; `rpm-ostree kargs` writes a new deployment with the new line, hence "reboot to apply".
- **`ujust`** = Bazzite's menu of maintenance scripts (`ujust --choose` shows them). When a recipe exists for something, use it — it does the ostree-correct thing.
- **Updates** download in the background and are applied at the next reboot (`ujust update` to trigger one by hand). Nothing changes under you while you're logged in.

**What persists across image updates — put every tweak here, nowhere else:**

| Persists | Doesn't |
|---|---|
| `/etc/**` (3-way merged; a file you modified is kept forever) — `fstab`, `sysctl.d`, `udev/rules.d`, `tuned/profiles`, `systemd/system`, `scx_loader`, `modprobe.d` | anything under `/usr` (read-only, replaced every update) |
| `/var/**` — `/var/home`, `/var/mnt` (`/mnt` is a symlink to it), `/var/usrlocal`, `/var/opt` | `/boot/loader/entries/*` edits (ostree rewrites them; use `rpm-ostree kargs`) |
| `rpm-ostree kargs`, `rpm-ostree install` layers, Flatpaks, Homebrew, removed Flatpaks (they are not reinstalled) | the kernel — it is version-locked in the image and cannot be swapped |

Check what you've changed under `/etc` any time: `sudo ostree admin config-diff`.

| Step | File |
|---|---|
| 0 | [Before the first boot](./bazzite/00-before-first-boot.md) — fstab + `tune2fs` from the installer shell, no chroot needed |
| 1 | [fstab](./bazzite/01-fstab.md) — root subvolumes on a HDD, games HDD under `/var/mnt` |
| 2 | [Update & rebase to DX](./bazzite/02-update-rebase-dx.md) — first boot: update, rebase to `bazzite-dx`, Docker, node/php/laravel/go via brew |
| 3 | [Debloat](./bazzite/03-debloat.md) — Flatpaks, autostarts; what not to remove |
| 4 | [Hardware](./bazzite/04-hardware.md) — LACT, CoolerControl, OverDrive karg |
| 5 | [Shell & CLI](./bazzite/05-shell-cli.md) — fish (in the image), Homebrew tools |
| 6 | [Performance](./bazzite/06-performance.md) — what the image already tunes, sched-ext LAVD, power profiles |
| 7 | [Kernel args](./bazzite/07-kargs.md) — SAFE / MAX via `rpm-ostree kargs` |
| 8 | [sysctl, tuned & HDD udev](./bazzite/08-sysctl-udev.md) — HDD tuning that tuned won't overwrite |
| 9 | [Rollback & backup](./bazzite/09-rollback.md) — pin the deployment, home backup |
| 10 | [Apps](./bazzite/10-apps.md) — Flatpak / brew / layering, Steam launch options |
| + | [Notes & reference](./bazzite/99-notes.md) |

Flow: `0 (installer shell) → first boot → 1 fstab → 2 update + DX → 3 → 4 → 5 → 6 → 7 → 8 → reboot → 9 pin → 10 apps`. Kargs and layered packages only take effect after a reboot; batch them.
