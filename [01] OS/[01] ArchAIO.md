# Arch Linux — archinstall → tuned desktop

Short, command-first post-install guide. Follow the numbered steps in order, choosing one desktop and skipping optional steps that do not apply. Explanations, tables and the "why" behind every choice live in [`arch/99-notes.md`](./arch/99-notes.md).

**Start point:** you ran `archinstall` with: profile **Minimal**, bootloader **systemd-boot**, kernel `linux`, **NetworkManager**, a user in `wheel`, filesystem **ext4** (separate `/home`) or **btrfs** (archinstall's default `@`/`@home` layout). Rebooted, logged in on a TTY. No desktop, no GPU driver. Keep the boot method chosen during installation: step 7 covers classic entries, while step 8 builds UKIs. Secure Boot is optional within step 8.

**Conventions:** `SAFE` = sane; `FAST` = max speed, no safety net. `<root-uuid>`, `<user>` are placeholders. Every `pacman -S` uses `--needed`.

Run blocks labelled `bash` in Bash, even after choosing fish in step 5: enter `bash` first. Configuration blocks belong in the named files. Sections labelled maintenance or recovery are for later use, not commands to run during setup.

| Step | File |
|---|---|
| 1 | [fstab](./arch/01-fstab.md) — first, before anything writes to the disks |
| 2 | [CachyOS repos](./arch/02-cachyos-repos.md) |
| 3 | Bare desktop, no meta packages: [KDE Plasma](./arch/03-kde.md) · [GNOME](./arch/03-gnome.md) · [Sway](./arch/03-sway.md) |
| 4 | [Essentials & hardware](./arch/04-essentials.md) (audio, AMD GPU + LACT, Bluetooth, fonts, storage, firewall) |
| 5 | [Shell & CLI](./arch/05-shell-cli.md) (fish, paru, tools, neovim) |
| 6 | [CachyOS speed stack](./arch/06-speed-stack.md) — zram, services, DNS and I/O defaults |
| 7 | [Kernel + command line](./arch/07-kernel.md) — classic systemd-boot entries; UKI users read the command-line section and continue to step 8 |
| 8 | [UKI + optional Secure Boot](./arch/08-secure-boot.md) — UKI users install and verify the kernel here; classic-entry users can skip this step |
| 9 | [sysctl](./arch/09-sysctl.md) — after booting and verifying the new kernel |
| 10 | [SSD swap alongside zram](./arch/10-ssd-swap.md) — optional, for memory-heavy workloads on 16 GB RAM or less; requires an SSD-backed Btrfs `@swap` mounted at `/swap` |
| 11 | [Extras](./arch/11-extras.md) — optional DNS-over-TLS, mic noise suppression and ADB |
| 12 | [HDD gaming tweaks](./arch/12-hdd-gaming.md) — optional, mechanical drives only |
| 13 | [Reboot, checks and Timeshift baseline](./arch/13-timeshift.md) — capture the configured OS before installing applications |
| 14 | [Applications & gaming](./arch/14-apps.md) — choose the applications you need |
| Reference | [Notes & reference](./arch/99-notes.md) — explanations and maintenance checks |

Flow: `1–6 → kernel setup at 7 or 8 → reboot & verify → 9–12 (skip optional steps as appropriate) → 13 reboot, checks & snapshot → 14 apps`.

At step 3, install and configure your chosen desktop; complete its **after first login** section after the reboot at the end of step 4. The kernel reboot in step 7 or 8 also activates the zram configuration from step 6. Step 13 checks that optional SSD swap survives a reboot before taking the baseline snapshot.

On an existing desktop, follow only the steps you need and their prerequisites. You do not need to repeat installation, kernel removal, key enrolment, or swapfile creation already completed.
