# System Optimization & Configuration Guides (sysopt)

Welcome to the `sysopt` repository! This collection contains various guides, configuration files, and notes primarily focused on setting up, optimizing, and customizing Arch Linux, along with network configurations and hardware-specific profiles.

## Table of Contents

1.  [Operating System Setups & Configurations](#1-operating-system-setups--configurations)
    - [Arch Linux All-In-One Guide](#arch-linux-all-in-one-guide)
2.  [Network & Router Configurations](#2-network--router-configurations)
    - [Arch Linux DNS Setup (dnsmasq & Stubby)](#arch-linux-dns-setup-dnsmasq--stubby)
    - [Bufferbloat Fix Guide](#bufferbloat-fix-guide)
3.  [Hardware Configurations & Profiles](#3-hardware-configurations--profiles)
    - [CoreCtrl Overclock Profile (AMD RX 570)](#corectrl-overclock-profile-amd-rx-570)

---

## 1. Operating System Setups & Configurations

This section houses comprehensive guides for operating system installation, post-installation steps, and deep customizations.

### Arch Linux All-In-One Guide

- **Files:** [`[01] OS/[01] ArchAIO.md`](./[01]%20OS/[01]%20ArchAIO.md) (index) + one short file per step in [`[01] OS/arch/`](./[01]%20OS/arch/), with all background in `arch/99-notes.md`
- **Description:** Command-first. Takes an `archinstall` Minimal install to a tuned desktop in a fixed order: `fstab` first (ext4/btrfs, HDD/SSD, extra drives — SAFE vs FAST options for every line), CachyOS repositories, a bare desktop built package-by-package with no meta packages (KDE Plasma, GNOME, or Sway), hardware essentials (PipeWire, AMD/RADV + LACT, fonts, codecs), fish/zsh + paru, the CachyOS speed stack (`cachyos-settings`, `ananicy-cpp`), `linux-cachyos` on systemd-boot with a verified SAFE/MAX kernel command line, sysctl, a Timeshift baseline, and only then applications and the Steam/Proton stack. Every package and option was checked against a live pacman database and upstream docs; an appendix lists the "tweaks" from older guides that are no-ops or harmful.

---

## 2. Network & Router Configurations

Guides and configurations related to improving network performance, DNS setup, and router tweaks.

### Arch Linux DNS Setup (dnsmasq & Stubby)

- **File:** [`[02] Network & Routers/archlinux-dot-dnsmasq-stubby-setup.md`](./[02]%20Network%20&%20Routers/archlinux-dot-dnsmasq-stubby-setup.md)
- **Description:** Instructions for configuring `dnsmasq` as a local DNS cache and forwarder, along with `Stubby` for DNS-over-TLS (DoT) to enhance privacy and security on Arch Linux.

### Bufferbloat Fix Guide

- **File:** [`[02] Network & Routers/bufferbloat_fix.md`](./[02]%20Network%20&%20Routers/bufferbloat_fix.md)
- **Description:** A guide discussing bufferbloat, its impact on network latency, and methods/configurations (e.g., SQM - Smart Queue Management) to mitigate it for a smoother internet experience.

---

## 3. Hardware Configurations & Profiles

Specific configuration files and profiles tailored for particular hardware components, often for performance tuning or custom setups.

### i3wm-like Keybinds for KDE Plasma 6

- **File Page:** [`[03] Hardware Configs/i3wm_keybinds_for_kde6.kksrc`](https://github.com/swapnanil/sysopt/blob/main/[03]%20Hardware%20Configs/i3wm_keybinds_for_kde6.kksrc)
- **Description:** A KDE Plasma 6 keyboard shortcuts file (`.kksrc`) providing i3wm-like keybindings for KWin. This file can be imported via `System Settings` > `Keyboard` > `Shortcuts` (or the appropriate KCM for custom shortcuts).
  - _To use:_ Download this file and import it into KDE's keyboard shortcut settings.

### CoreCtrl Overclock Profile (AMD RX 570)

- **File Page:** [`[03] Hardware Configs/corectrl_oc_570.ccpro`](https://github.com/swapnanil/sysopt/blob/main/[03]%20Hardware%20Configs/corectrl_oc_570.ccpro)
- **Description:** A saved `CoreCtrl` application profile (`.ccpro` file) containing overclocking and fan control settings for an AMD Radeon RX 570 graphics card.
  - _To use:_ Download this file and import it into the CoreCtrl application.
