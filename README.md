# System Optimization & Configuration Guides (sysopt)

Welcome to the `sysopt` repository! This collection contains various guides, configuration files, and notes primarily focused on setting up, optimizing, and customizing Arch Linux, along with network configurations and hardware-specific profiles.

## Table of Contents

1.  [Operating System Setups & Configurations](#1-operating-system-setups--configurations)
    - [Arch Linux All-In-One Guide](#arch-linux-all-in-one-guide)
    - [Bazzite Performance Guide](#bazzite-performance-guide)
    - [Windows 11 Minimal Install Guide](#windows-11-minimal-install-guide)
2.  [Network & Router Configurations](#2-network--router-configurations)
    - [Arch Linux DNS Setup (dnsmasq & Stubby)](#arch-linux-dns-setup-dnsmasq--stubby)
    - [Bufferbloat Fix Guide](#bufferbloat-fix-guide)
    - [SQM switch for an OpenWrt bridge](#sqm-switch-for-an-openwrt-bridge)
3.  [Hardware Configurations & Profiles](#3-hardware-configurations--profiles)
    - [CoreCtrl Overclock Profile (AMD RX 570)](#corectrl-overclock-profile-amd-rx-570)
4.  [Local LLM](#4-local-llm)
    - [llama.cpp on an AMD GPU under Windows 11](#llamacpp-on-an-amd-gpu-under-windows-11)
    - [llama.cpp on an AMD GPU under CachyOS / Arch](#llamacpp-on-an-amd-gpu-under-cachyos--arch)
5.  [Software Configs](#5-software-configs)
    - [MangoHud](#mangohud)
    - [EQ presets for an IEM](#eq-presets-for-an-iem)

---

## 1. Operating System Setups & Configurations

This section houses comprehensive guides for operating system installation, post-installation steps, and deep customizations.

### Arch Linux All-In-One Guide

- **Files:** [`[01] OS/[01] ArchAIO.md`](./[01]%20OS/[01]%20ArchAIO.md) (index) + one short file per step in [`[01] OS/arch/`](./[01]%20OS/arch/), with all background in `arch/99-notes.md`
- **Description:** Command-first. Takes an `archinstall` Minimal install to a tuned desktop in a fixed order: `fstab` first (ext4/btrfs, HDD/SSD, extra drives — SAFE vs FAST options for every line), CachyOS repositories, a bare desktop built package-by-package with no meta packages (KDE Plasma, GNOME, or Sway), hardware essentials (PipeWire, AMD/RADV + LACT, fonts, codecs), fish/zsh + paru, the CachyOS speed stack (`cachyos-settings`, `ananicy-cpp`), `linux-cachyos` on systemd-boot with a verified SAFE/MAX kernel command line, sysctl, a Timeshift baseline, and only then applications and the Steam/Proton stack. Every package and option was checked against a live pacman database and upstream docs; an appendix lists the "tweaks" from older guides that are no-ops or harmful. Optional last step: Secure Boot with your own keys, a signed unified kernel image, kernel lockdown and TPM measured boot, with Windows dual boot kept.

---

### Bazzite Performance Guide

- **Files:** [`[01] OS/[03] Bazzite.md`](./[01]%20OS/[03]%20Bazzite.md) (index) + step files in [`[01] OS/bazzite/`](./[01]%20OS/bazzite/)
- **Description:** The Arch guide's tweaks for the immutable Bazzite KDE image, restricted to what survives ostree/bootc updates (`/etc`, `/var`, `rpm-ostree kargs`, layers, Flatpak/Homebrew): fstab for a HDD root + games HDD under `/var/mnt`, debloat, LACT, fish + brew, what the image already tunes vs. what to add (tuned profiles for the zram memory policy the image lacks, HDD udev rule, sched-ext bpfland — not LAVD, which stalls on the 7.2 kernel, SAFE/MAX kernel args), deployment pinning and rollback, apps.

---

### Windows 11 Minimal Install Guide

- **Files:** [`[01] OS/[04] Windows.md`](./[01]%20OS/[04]%20Windows.md) (index) + step files, scripts and templates in [`[01] OS/win/`](./[01]%20OS/win/)
- **Description:** Windows 11 Pro built from Microsoft's own files and installed without clicks. Covers building a Pro-only ISO with UUP dump (latest cumulative update included, no Edge, no Store, one inbox app), filling in the unattend generator option by option, a disk script that makes two partitions and stops if it can't tell which disk to use, and three first-logon scripts for performance, privacy and interface that stick to documented policies. Nothing is patched or removed after install, so Defender and Windows Update keep working. Comes with a placeholder answer file to import into the generator. Assumes at least a Ryzen 5 3600 class CPU and 16 GB of RAM. Optional last step: a TinyWall allowlist for the Windows components.

---

## 2. Network & Router Configurations

Guides and configurations related to improving network performance, DNS setup, and router tweaks.

### Arch Linux DNS Setup (dnsmasq & Stubby)

- **File:** [`[02] Network & Routers/archlinux-dot-dnsmasq-stubby-setup.md`](./[02]%20Network%20&%20Routers/archlinux-dot-dnsmasq-stubby-setup.md)
- **Description:** Instructions for configuring `dnsmasq` as a local DNS cache and forwarder, along with `Stubby` for DNS-over-TLS (DoT) to enhance privacy and security on Arch Linux.

### Bufferbloat Fix Guide

- **File:** [`[02] Network & Routers/bufferbloat_fix.md`](./[02]%20Network%20&%20Routers/bufferbloat_fix.md)
- **Description:** A guide discussing bufferbloat, its impact on network latency, and methods/configurations (e.g., SQM - Smart Queue Management) to mitigate it for a smoother internet experience.

### SQM switch for an OpenWrt bridge

- **Files:** [`[02] Network & Routers/sqm-toggle.md`](./[02]%20Network%20&%20Routers/sqm-toggle.md) with `sqm.cmd` (Windows) and `sqm.sh` (Linux)
- **Description:** A small menu, or one command, that turns the cake shaper on an OpenWrt box on or off from the PC behind it, or reads its state. One SSH session per action, so one password prompt until the menu's key item installs a key. Handles the dropped session that stopping the shaper causes, needs no administrator rights or network changes on the PC, stores no password.

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

---

## 4. Local LLM

Running language models on your own hardware: building the runtime, launching it correctly, and knowing what to expect from it.

### llama.cpp on an AMD GPU under Windows 11

- **Files:** [`[05] Local LLM/[01] Windows.md`](./[05]%20Local%20LLM/[01]%20Windows.md) (index) + step files and scripts in [`[05] Local LLM/windows/`](./[05]%20Local%20LLM/windows/); the OS-independent reality check and model-choice files in [`[05] Local LLM/common/`](./[05]%20Local%20LLM/common/)
- **Description:** Measurement-first. Builds `llama.cpp` from source for a single AMD GPU target with the ROCm 10.1 (TheRock) SDK on Windows 11: every dependency in install order (ROCm Adrenalin driver, TheRock tarball, VS Build Tools, Windows SDK, CMake, Ninja), the CMake configure that uses the correct compiler driver, a thirty-second check that the GPU kernels are actually optimized, and the memory rules for a 16 GB machine. Then the launch script flag by flag, split into machine-wide flags and per-model flags, with the llama-bench results behind each choice (micro-batch size at depth, KV cache precision, speculative decoding from the model's own draft head, sampling defaults and reasoning effort), a five-minute tuning procedure for any new model, and a prompt that produces launch flags from a model name. Ends with a measured comparison against hosted frontier models and a short list of what would still help. Written against an RX 9070 16 GB, a Ryzen 5 3600 and 16 GB of RAM; other RDNA 3 and 4 cards change one target name.

### llama.cpp on an AMD GPU under CachyOS / Arch

- **Files:** [`[05] Local LLM/[02] Linux.md`](./[05]%20Local%20LLM/[02]%20Linux.md) (index) + step files and scripts in [`[05] Local LLM/linux/`](./[05]%20Local%20LLM/linux/)
- **Description:** The same machine under CachyOS with Sway, on top of the Arch guide. Setup first: the distribution's `llama-cpp` package already carries the Vulkan and ROCm backends, so a model runs in ten minutes with no build and no SDK. Then the optional from-source build for one GPU target with both backends in one binary (three pacman packages, no compiler-driver trap), a benchmark script that selects the backend, the launcher with a Sway keybinding and an optional systemd user unit, and a system-tuning file that says what the Arch guide already handled, which two LACT knobs matter, and what does nothing. The card-level flag measurements carry over from the Windows guide; Linux-specific numbers are marked as expectations until measured.

---

## 5. Software Configs

Ready-to-use configuration files for individual programs.

### MangoHud

- **Files:** [`[04] Software Configs/MangoHud/`](./[04]%20Software%20Configs/MangoHud/)
- **Description:** `MangoHud.conf` and `presets.conf` for the in-game overlay, with the font they expect. Copy to `~/.config/MangoHud/`.

### EQ presets for an IEM

- **Files:** [`[04] Software Configs/EQ/`](./[04]%20Software%20Configs/EQ/) (`README.md`, `EQ.py`, generated `windows/` and `linux/` folders)
- **Description:** 25 equaliser presets for one budget single dynamic driver IEM, in five confidence tiers and five use cases (music, two gaming profiles, movies, bass), each as an Equalizer APO text file for Windows and an Easy Effects JSON for Linux with identical filters. The generator takes a table of filters, computes a clipping-safe preamp from the combined response, and writes both formats, so it serves any other IEM once its frequency response is known. The README explains what each filter corrects, how to judge the tiers by ear, and how to find your own treble peaks with a sine sweep.
