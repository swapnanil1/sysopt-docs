# Arch Linux — archinstall → tuned desktop

Short, command-first guide. One file per step, in the order they must run. Explanations, tables and the "why" behind every choice live in [`arch/99-notes.md`](./arch/99-notes.md).

**Start point:** you ran `archinstall` with: profile **Minimal**, bootloader **systemd-boot**, kernel `linux`, **NetworkManager**, a user in `wheel`, filesystem **ext4** (separate `/home`) or **btrfs** (archinstall's default `@`/`@home` layout). Rebooted, logged in on a TTY. No desktop, no GPU driver.

**Conventions:** `SAFE` = sane; `FAST` = max speed, no safety net. `<root-uuid>`, `<user>` are placeholders. Every `pacman -S` uses `--needed`.

| Step | File |
|---|---|
| 1 | [fstab](./arch/01-fstab.md) — first, before anything writes to the disks |
| 2 | [CachyOS repos](./arch/02-cachyos-repos.md) |
| 3 | Bare desktop, no meta packages: [KDE Plasma](./arch/03-kde.md) · [GNOME](./arch/03-gnome.md) · [Sway](./arch/03-sway.md) |
| 4 | [Essentials & hardware](./arch/04-essentials.md) (audio, AMD GPU + LACT, Bluetooth, fonts, storage, firewall) |
| 5 | [Shell & CLI](./arch/05-shell-cli.md) (fish, paru, tools, neovim) |
| 6 | [CachyOS speed stack](./arch/06-speed-stack.md) |
| 7 | [Kernel + command line](./arch/07-kernel.md) (`linux-cachyos`, systemd-boot, SAFE/MAX cmdline) |
| 8 | [sysctl](./arch/08-sysctl.md) |
| 9 | [Checks, Timeshift baseline, reboot](./arch/09-timeshift.md) |
| 10 | [Applications & gaming](./arch/10-apps.md) — only after the snapshot |
| + | [Extras](./arch/11-extras.md) (DNS-over-TLS, mic noise suppression, ADB) · [Notes & reference](./arch/99-notes.md) |

Flow: `1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → reboot & verify kernel → 9 snapshot → 10 apps`.
