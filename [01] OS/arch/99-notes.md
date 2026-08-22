# Notes & reference

The "why" behind the step files, verified August 2026 against a live pacman DB (Arch + CachyOS repos), kernel docs and the Arch Wiki. Reference machine: Ryzen 5 3600, RX 9070, B550M, systemd-boot, ext4 on a SATA HDD + games HDD, zram.

## 1 fstab

**Options that do nothing on kernel 6.x/7.x** (fs/ext4/super.c): `nobh` removed since 3.4 ("Ignoring removed nobh option"); `delalloc`, `auto_da_alloc`, `block_validity`, `nodiscard`, `data=ordered`, `barrier=1` are defaults; `dioread_nolock` default since 5.6; `journal_checksum` auto with `metadata_csum` (Arch default); `journal_async_commit` refuses to mount with `data=ordered`. Only `noatime`, `lazytime`, `errors=remount-ro`, `commit=N`, `data=writeback`, `barrier=0` do anything.

- `errors=remount-ro` is **not** redundant: Arch's `mke2fs.conf` has no `errors=` line, so fresh ext4 defaults to `errors=continue`.
- `commit=N`: journal commit interval. Data pages are still flushed at `vm.dirty_expire_centisecs` (30 s default), so `commit=120/180` widens the metadata-loss window without extra speed. 60 is the sweet spot.
- `data=writeback`: metadata may commit before data; crash → recently written files can hold stale blocks, no fs corruption. ext4 cannot change data mode on remount, and `systemd-remount-fs` failing drops *all* root fstab options for that boot — hence `tune2fs -o journal_data_writeback` or `rootflags=`.
- `barrier=0`: skips cache flush/FUA after journal commits. Consumer drives have volatile write caches; Arch Wiki: "can lead to severe file system corruption and data loss". UPS only.
- `user`/`users` implies `noexec,nosuid,nodev` → games on that drive won't launch. `defaults` already has `exec`; ownership is `chown`.
- `nofail` alone still waits the 90 s device timeout for a missing disk → `x-systemd.device-timeout=15` (never 0 = infinite).
- `x-gvfs-show` is the documented form; `comment=x-gvfs-show` only works because gvfs does a substring match (its source calls it a bug people rely on). KDE ignores both.
- ESP: `fmask=0077,dmask=0077` keeps `bootctl` from warning about the random-seed file; `iocharset=ascii`, `codepage=437`, `utf8`, `errors=remount-ro` are vfat kernel defaults.
- btrfs: `subvolid=` breaks after a Timeshift restore (restored `@` has a new id); compression/`nodatacow` are filesystem-wide (first mounted subvolume wins → identical option strings); `autodefrag` breaks reflinks → snapshots balloon; `discard=async` default since 6.2, `space_cache=v2` default, `ssd` autodetected; swapfile inside `@` breaks snapshots. With the ESP at `/boot`, kernels are outside snapshots.
- `genfstab` copies current mount options, sets passno 1/2/0(btrfs), strips `subvolid`, appends (`>>`).
- Swap = zram (`cachyos-settings`: `zram-size = ram`, zstd, prio 100). I/O schedulers = `cachyos-settings` `60-ioschedulers.rules` (HDD bfq, SATA SSD mq-deadline, NVMe kyber).

## 2 CachyOS repos

`cachyos-repo.sh`: imports key `F3B607488DB35A47`, `pacman -U` of keyring + mirrorlists + **CachyOS's patched pacman** (stock pacman cannot expand `$arch_v3` or accept `x86_64_v3` packages), detects ISA (`znver4/5` → znver4 repos; else v4; else v3; CPUs without v3 get nothing), inserts the blocks **before `[core]`**, sets `Architecture = auto`, backs up to `/etc/pacman.conf.bak`, runs `pacman -Syu`. `--remove` reverts.

pacman takes the *first* repo that carries a name regardless of version — that is how v3 rebuilds shadow `core`/`extra`. Side effects: `[cachyos]` `umu-launcher`/`gamescope` can be a release behind `multilib`/`extra` (intentional pins); there is **no multilib-v3**, so `[multilib]` must be enabled. `cachyos-rate-mirrors` ranks Arch + CachyOS lists, prepends CachyOS's CDN, and its hook disables `reflector.timer`.

## 3 Desktops

Virtual deps that make pacman prompt (or pick the wrong first provider with `--noconfirm`): `pulse-native-provider` (plasma-pa, gnome-settings-daemon → `pipewire-pulse` vs pulseaudio), `jack` (ffmpeg/mpv → `pipewire-jack` vs jack2), `ttf-font` (sddm, webkitgtk, sway → any Noto/DejaVu), `qt6-multimedia-backend` (→ `qt6-multimedia-ffmpeg`), `pipewire-session-manager` (→ `wireplumber`), `emoji-font` (→ `noto-fonts-emoji`). The Tier-0 lines name these.

**KDE.** `plasma-desktop` pulls ~500 packages; `powerdevil` is a hard dep. `kscreen`, `plasma-nm`, `plasma-pa`, `bluedevil`, `kwallet-pam`, `breeze-gtk`, `kde-gtk-config`, `spectacle`, `plasma-systemmonitor` are optdeps only. `plasma-meta` 6.7-2 switched from `sddm` to `plasma-login-manager` (`plasmalogin.service`, `/etc/plasmalogin.conf`, PAM files with `pam_kwallet5` included). kwin is Wayland-only since 6.4; the X11 session (`plasma-x11-session` + `kwin-x11`) is slated for removal in 6.8. `kate` replaced `kwrite`; `maliit-keyboard` → `plasma-keyboard`; `qt6-wayland` not needed (QPA plugin is in `qt6-base`). Size traps: `spectacle` (opencv+tesseract ~120 MiB), `kdegraphics-thumbnailers` (ghostscript 47 MiB), `plasma-workspace-wallpapers` (254 MiB), `okular` (phonon-qt6-vlc + libvlc). `packagekit-qt6`: the package's own optdep text says "not recommended". kwallet-pam conditions: wallet `kdewallet`, blowfish, password = login, no passwordless autologin. `pavucontrol-qt` is LXQt's mixer, not Plasma's.

**GNOME.** `gnome-shell → gnome-session → xdg-desktop-portal-gnome → nautilus → gvfs, localsearch, tinysparql` — unavoidable. `gdm` provides screen locking. `gnome-keyring` and `evolution-data-server` are optdeps only. `gnome-control-center` hard-pulls `gnome-online-accounts`, `geoclue` (location off by default), `bluez`. GNOME 50: Wayland-only (mutter dropped X11), `papers`/`showtime`/`snapshot` replaced `evince`/`totem`/`cheese`, UI font Adwaita Sans (`adwaita-fonts`; `cantarell-fonts` obsolete), VRR + fractional scaling on by default, `gnome-console` (`kgx`) is the core terminal (Files' "Run as a Program" hard-codes it). `gnome-software`'s pacman backend is disabled on Arch and it downloads updates by default. Empty user list on the GDM 50 greeter: `/etc/dconf/profile/gdm` must contain `user-db:user` / `system-db:gdm` / `file-db:/usr/share/gdm/greeter-dconf-defaults`, then `sudo dconf update`. SSH agent is `gcr-ssh-agent.socket` (gcr-4), not gnome-keyring. Never `Alt+F2 r` on Wayland (kills the session). Extensions from `[cachyos]`: dash-to-dock, no-overview; AUR: blur-my-shell, gsconnect, tiling-assistant, clipboard-indicator.

**Sway.** `sway` depends on virtual `ttf-font` (Nerd fonts don't provide it). `seatd` is only libseat; logind + polkit give the seat — never enable `seatd.service`. sway 1.12 ships `/usr/share/xdg-desktop-portal/sway-portals.conf` (`default=gtk`, ScreenCast/Screenshot=wlr) and `/etc/sway/config.d/50-systemd-user.conf` (env import + `dbus-update-activation-environment`) — a user `portals.conf` with `default=wlr` overrides it and breaks every file dialog. `ly` reads `/usr/share/wayland-sessions`, sets `XDG_CURRENT_DESKTOP=sway:wlroots`, its PAM unlocks gnome-keyring, and `/etc/environment` applies (pam_env). `systemctl --user set-environment` only affects systemd-launched apps — apps launched from sway inherit sway's env. `nm-applet` needs `--indicator` (SNI; XEmbed trays don't exist on Wayland). `gnome-keyring`'s `ssh` component is gone since 1:46. `flameshot` on wlroots works only through the portal with a `for_window` rule. Obsolete env: `MOZ_ENABLE_WAYLAND` (Firefox 121+), `ELECTRON_OZONE_PLATFORM_HINT` (Electron ≥38.2), `GDK_BACKEND`, `SDL_VIDEODRIVER` (SDL3), `XDG_*` (ly sets them). `xf86-video-amdgpu`/`-ati` are X.org DDX drivers — unused by wlroots and XWayland.

## 4 Essentials & hardware

- **PipeWire realtime**: out of the box PipeWire asks RTKit and falls back to no RT (`ps -eLo rtprio,policy,comm | grep data-loop` → `TS`). SAFE = `rtkit` (per-thread grant + runaway watchdog). FAST = `audio` group, because `cachyos-settings` ships `limits.d/20-audio.conf` (`@audio rtprio 99, nice -11`) — Arch Wiki warns the audio group breaks fast user switching. `realtime-privileges` is a third mechanism; pick one.
- **GPU**: `mesa` includes VA-API (`libva-mesa-driver` merged in; `mesa-vdpau` gone); `vulkan-radeon` is not pulled by compositors (they only need the loader); `vulkan-icd-loader`, `lib32-vulkan-icd-loader`, `vulkan-mesa-implicit-layers` are deps of it. Install `lib32-vulkan-radeon` before `steam` or pacman prompts with `lib32-nvidia-utils` first. `amdvlk` removed. `xf86-video-amdgpu` is X11 DDX only.
- **LACT**: socket is `wheel`-owned (no polkit rule); ≥0.7.5 + ppd ≥0.30 resolve the `amdgpu_dpm` conflict automatically. RDNA3/4 need OverDrive even for fan curves: `ppfeaturemask = default | 0x4000` (`0xfff7ffff` on this card). `0xffffffff` enables unstable bits (Arch Wiki: flicker / broken resume) for no gain. `coolercontrol` is in `[cachyos]` (repo package conflicts with the AUR `-bin`).
- **NVIDIA (not covered, for reference)**: `nvidia`/`nvidia-dkms` no longer exist → `nvidia-open`/`nvidia-open-dkms`; prebuilt `linux-cachyos-<flavour>-nvidia-open` needs no DKMS; `[cachyos]`'s `nvidia-open-dkms` doesn't depend on `nvidia-utils` — list it; `nvidia_drm.modeset=1` default since 560.
- **Storage**: `exfatprogs` not `exfat-utils`; kernel `ntfs3` not `ntfs-3g`; udisks2 mounts NTFS with `windows_names` (breaks Proton on NTFS → `/etc/udisks2/mount_options.conf`: `[defaults]` `ntfs:ntfs_defaults=uid=$UID,gid=$GID`); `7zip` replaced `p7zip`; `gstreamer-vaapi` → `gst-plugin-va`; `opencl-rusticl-mesa` → `opencl-mesa`. `cachyos-settings` `69-hdparm.rules` runs `hdparm -B 254 -S 0` on rotational ATA disks but `hdparm` is not a dependency → silent no-op until installed. SAFE override: `/etc/udev/rules.d/69-hdparm.rules` with `-B 127 -S 120`.
- **Fonts**: `noto-fonts` + `ttf-hack` via plasma-integration (KDE); `adwaita-fonts` via GTK; `ttf-liberation` = Arial/Times metrics, fixes Steam "missing text"; `ttf-jetbrains-mono-nerd` is 228 MiB vs `ttf-jetbrains-mono` + `ttf-nerd-fonts-symbols-mono` ≈ 10 MiB; `noto-fonts-cjk` 299 MiB.
- **Codecs**: `x264`, `x265`, `lame` are ffmpeg deps; KDE has ffmpeg via `kpipewire`/`qt6-multimedia-ffmpeg`; the GStreamer set is GNOME-only.
- **Services/groups**: `systemd-resolved`/`timesyncd` are preset-enabled; `cachyos-settings` forces NM `dns=systemd-resolved` (resolved must run). `cronie` has no consumer, `acpid` double-handles power keys with logind, `avahi-daemon` conflicts with resolved's mDNS (the `avahi` library package is pulled anyway). Under logind only `wheel` matters — `/dev/dri/renderD*` and `/dev/kfd` are 0666, `card*` gets a session ACL; `audio`/`video`/`input`/`render` are pre-systemd leftovers.
- **Flatpak**: the Arch package adds the Flathub system remote itself; Flatpak Steam needs `game-devices-udev` (AUR) instead of `steam-devices` — prefer repo Steam.

## 5 Shell

fish's `.INSTALL` registers it in `/etc/shells`; `chsh` is util-linux and asks your password. Never root's shell (non-POSIX; `sudo -i`, rescue, hooks expect Bourne). `config.fish` is read by non-interactive fish too → keep output inside `status is-interactive`. fish 4 keeps abbreviations only in config files. `fish_add_path` without `-g` persists in `fish_variables` even after deleting the line. fish doesn't read `/etc/profile.d` on TTY login. `abbr` for pacman shortcuts (real command in history, scripts unaffected), `alias` only for `ls`/`cat` swaps; `alias ls='eza -al'` from older guides makes every `ls` a long listing.

zsh `~/.zshrc` (write it before the first launch or `zsh-newuser-install` runs):

```zsh
export EDITOR=nvim VISUAL=nvim
typeset -U path; path=(~/.local/bin $path)
HISTFILE=~/.zsh_history; HISTSIZE=50000; SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE SHARE_HISTORY AUTO_CD
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
alias update='sudo pacman -Syu && paru -Sua' pi='sudo pacman -S --needed' prs='sudo pacman -Rns' pq='pacman -Qs' vim=nvim
alias orphans='sudo pacman -Rns $(pacman -Qtdq)'
command -v eza >/dev/null && alias ls='eza --group-directories-first --icons=auto' ll='eza -l --group-directories-first --icons=auto --git' la='eza -la --group-directories-first --icons=auto --git'
command -v bat >/dev/null && alias cat='bat --paging=never'
command -v fzf    >/dev/null && source <(fzf --zsh)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh   # last
```

Keep `/etc/zsh/zprofile`'s `emulate sh -c 'source /etc/profile'` line. paru: `[cachyos]` binary; `SkipReview`/`MFlags=--skippgpcheck` are the only FAST options and both remove AUR safety; `SudoLoop`, `BottomUp`, `NewsOnUpgrade`, `RemoveMake` are safe. `man-db`, `man-pages`, `less` are not in a minimal install. `bind` just for `dig` pulls a DNS server's libs → `doggo` or `resolvectl query`. LazyVim requires git, a C compiler, `tree-sitter-cli`; not `python-pynvim`/`nodejs`/`npm`; back up all four nvim dirs and `rm -rf ~/.config/nvim/.git`.

## 6 Speed stack

`cachyos-settings` 1:1.4.0 ships (read from the package):

| File | Effect |
|---|---|
| `sysctl.d/70-cachyos-settings.conf` | `vm.swappiness=100`, `vfs_cache_pressure=50`, `dirty_bytes=256M`/`dirty_background_bytes=64M`, `dirty_writeback_centisecs=1500`, `page-cluster=0`, `kernel.nmi_watchdog=0`, `unprivileged_userns_clone=1`, `printk=3 3 3 3`, `kptr_restrict=2`, `netdev_max_backlog=4096`, `fs.file-max` |
| `udev/30-zram.rules` | at zram init: `vm.swappiness=150` (after sysctl.d — overrides it) + zswap off |
| `udev/60-ioschedulers.rules`, `50-sata.rules`, `69-hdparm.rules` | bfq/mq-deadline/kyber; SATA ALPM `max_performance`; `hdparm -B 254 -S 0` on HDDs |
| `udev/20-audio-pm.rules`, `99-cpu-dma-latency.rules`, `40-hpet-permissions.rules` | HDA power-save off on AC; `/dev/cpu_dma_latency`, rtc/hpet → group `audio` |
| `systemd/zram-generator.conf` | `zram-size = ram`, zstd, priority 100 |
| `modprobe.d/blacklist.conf`, `amdgpu.conf`, `nvidia.conf` | watchdogs `iTCO_wdt`/`sp5100_tco` off; GCN1/2 → amdgpu; NVIDIA `NVreg_InitializeSystemMemoryAllocations=0` |
| `modules-load.d/ntsync.conf` | ntsync for Wine/Proton |
| `tmpfiles.d/thp.conf`, `thp-shrinker.conf`, `coredump.conf` | THP `defrag=defer+madvise`, `max_ptes_none=409` (THP=always without RAM bloat), coredumps pruned after 3 d |
| `system.conf.d/00-timeout.conf`, `10-limits.conf` (+user) | `DefaultTimeoutStopSec=10s`, NOFILE raised |
| `journald.conf.d/00-journal-size.conf` | `SystemMaxUse=50M` |
| `NetworkManager/conf.d/dns.conf`, `timesyncd.conf.d/10-timesyncd.conf` | `dns=systemd-resolved`; Cloudflare/Google NTP |
| `limits.d/20-audio.conf` | `@audio rtprio 99, nice -11` |
| `/usr/bin/game-performance` | `systemd-inhibit … powerprofilesctl launch -p performance -- "$@"` |
| `/usr/bin/kerver`, `zink-run`, `pci-latency` (+ disabled service) | kernel/ISA summary; GL-on-Vulkan; legacy PCI latency timer (no-op on PCIe) |

Hard deps: `zram-generator`, `ananicy-cpp`, `cachyos-ananicy-rules`, `inxi`, `iw`, `wireless-regdb`. Override anything with a same-named file under `/etc`. `ananicy-cpp` renices by process name (games nice -5) — never together with `gamemode` (CachyOS wiki). `cachyos-hello` is the ISO welcome app (links/buttons), nothing depends on it. `cachyos-hooks` rewrites `/etc/os-release` to CachyOS. `linux-cachyos-headers` pulls clang/llvm/lld (LTO kernel); `-bore-headers` doesn't.

## 7 Kernel & cmdline

Kernels (`pacman -Si`, CachyOS wiki): `linux-cachyos` = tuned EEVDF, Clang ThinLTO + AutoFDO, 1000 Hz (upstream default); `-bore` = BORE scheduler, GCC; `-lts`; avoid `-rt-bore`, `-server`, `-hardened`, `-bmq` on a desktop. `pacman -Rns linux` runs the mkinitcpio remove hook immediately (deletes `/boot/vmlinuz-linux` + initramfs + the module dir) — hence install → entry → reboot → verify → remove. mkinitcpio 41 ships `PRESETS=('default')` only: **no fallback initramfs for any kernel by default**. With the `microcode` HOOK the separate `initrd /amd-ucode.img` line is redundant (harmless).

| Parameter | Tier | Verified effect |
|---|---|---|
| `nowatchdog` | SAFE | both lockup detectors off; `nmi_watchdog=0`/`nosoftlockup` are subsets |
| `audit=0` | SAFE | no audit syscall hooks; nothing on a desktop needs auditd |
| `zswap.enabled=0` | SAFE | kernel has `CONFIG_ZSWAP_DEFAULT_ON=y`; zswap in front of zram double-compresses |
| `iommu=pt` | SAFE | IOMMU stays initialised (VFIO possible), host devices identity-mapped |
| `usbcore.autosuspend=-1` | SAFE | no USB idle suspend (DAC pops, mouse wake lag) |
| `quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=auto` | SAFE | silent boot; `quiet` before `loglevel`; `udev.log_priority` is the obsolete name |
| `mitigations=off` | MAX | Arch Wiki: ≤5 % on Zen 2+; subsumes `spectre_v2=off`, `nospectre_v1` |
| `init_on_alloc=0` | MAX | no zeroing of new kernel allocations (`CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y`); `init_on_free=0` already default |
| `randomize_kstack_offset=off` | MAX | a few instructions per syscall |
| `amd_iommu=off` | MAX | no IOMMU at all → no VFIO ever; tiny gain over `pt` |
| `pcie_aspm.policy=performance` | MAX | links never L0s/L1; most desktop firmware has ASPM off anyway |
| `ahci.mobile_lpm_policy=1` | plain Arch | integer param (0 firmware, **1 max_performance**, 2 medium, 3 med+dipm, 4/5 min); `=max_performance` is rejected (`journalctl -k`: "invalid for parameter"); redundant with `50-sata.rules` |
| `amdgpu.ppfeaturemask=0xfff7ffff` | LACT only | default `0xfff7bfff` \| `0x4000` |

No-ops on the CachyOS kernel / this CPU: `split_lock_detect=off` (no `split_lock_detect`/`bus_lock_detect` flag on Ryzen; setup returns early), `scsi_mod.scan=async` (`CONFIG_SCSI_SCAN_ASYNC=y`), `amd_pstate=active` (kernel default), `preempt=full` (`Dynamic Preempt: full`), `transparent_hugepage=always` (`CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y`), `tsc=reliable`/`clocksource=tsc`, `amdgpu.dcdebugmask=0x10` (PSR = eDP laptop panels). Harmful: `processor.max_cstate=1`/`idle=poll` (heat; less boost headroom on Zen; PM-QoS via `/dev/cpu_dma_latency` is the proper tool), `threadirqs`, `nohz_full`, `skew_tick=1`, `psi=0` (breaks oomd/monitors), `nvme_core.default_ps_max_latency_us=0` (only for APST-broken drives). `loader.conf` `editor yes` lets anyone at the keyboard boot `init=/bin/sh`.

## 8 sysctl

Already set: Arch `10-arch.conf` (`vm.max_map_count=1048576`, `fs.inotify.max_user_watches=524288`), systemd `50-default.conf` (`kernel.sysrq=16`, `default_qdisc=fq_codel`), `70-cachyos-settings.conf`, CachyOS kernel defaults (`kernel.split_lock_mitigate=0`, `vm.compaction_proactiveness=0`, `vm.watermark_boost_factor=0`). **`vm.max_map_count=262144` in `80-gamecompatibility.conf` lowers Arch's value 4×** (SteamOS uses 2147483642; it's a compatibility knob, not speed).

Precedence: `/etc/sysctl.d/99-*` beats `/usr/lib/sysctl.d/70-*` at `systemd-sysctl` time, but `30-zram.rules` fires later at zram init and sets `vm.swappiness=150` — only a udev rule (`/etc/udev/rules.d/30-zram.rules`, keep the zswap line) can change it. 150 is right for zram (kernel docs: >100 for in-memory swap; with an HDD filesystem, higher — compressing idle pages beats re-reading page cache from disk). `dirty_ratio` ↔ `dirty_bytes` are exclusive (writing one zeroes the other; `= 0` is rejected). `kernel.sched_*` tunables moved to debugfs in 5.13.

Knobs: `vfs_cache_pressure` 20 on HDD (never 0); `dirty_*_bytes` 128M/32M on HDD (10 % of 16 GiB ≈ 1.5 GiB ≈ 10–15 s of stalled HDD writeback); `dirty_expire_centisecs` 6000 = twice the data lost on a crash for nothing; `watermark_scale_factor=125` (kswapd earlier, fewer foreground stalls, ~1.25 % RAM); `page-cluster=0` with zram. Placebo: `vm.page_lock_unfairness=1`, `vm.zone_reclaim_mode=0`. BBR: CachyOS kernels ship `tcp_bbr3` (name `bbr3`) and `tcp_bbr` (`bbr`); both and `sch_cake` auto-load on sysctl write; client BBR mostly helps uploads. CPU: amd-pstate active/EPP is the kernel default; ppd *balanced* = governor `powersave` + EPP `balance_performance`, *performance* = both `performance`; ppd only works in active mode; its saved profile did not survive a reboot on the reference box → oneshot unit. `game-performance` = `powerprofilesctl launch -p performance` (a hold).

## 9 Timeshift

`timeshift` hard-depends on gtk3, vte3, xapp, cronie (cron jobs are only written when a schedule is on). btrfs mode: `@`/`@home` as direct children of the top level, default subvolume 5, `subvol=` in fstab and `rootflags=subvol=@` on the cmdline; snapshots are writable subvolumes under `/timeshift-btrfs/snapshots/` of the top level; restore = `mv @ → snapshot dir` + `btrfs subvolume snapshot <chosen>/@ /@` (new subvolid). rsync mode: `rsync -aii --delete --link-dest=<prev>` without `-x`, so `/boot` (ESP) is captured; `/home/*/**`, `/mnt/*`, `/var/cache/pacman/pkg/*` excluded by default; destination must be a Linux filesystem; with no `--snapshot-device` the first run picks the first Linux partition it finds; whole-disk filesystems without a partition table may be hidden (`--list-devices`). `--tags D` = daily → auto-pruned past `count_daily` unless commented; `O` never pruned. Restore prompt defaults to "Re-install GRUB2?" → `--skip-grub`. systemd-boot + btrfs: Timeshift never touches the ESP or runs mkinitcpio — rollback across a kernel upgrade needs a chroot + kernel reinstall. Neither the Arch nor the CachyOS live ISO ships timeshift. `timeshift-autosnap` (AUR): PreTransaction hook on `Upgrade` only, `AbortOnFail`, `/etc/timeshift-autosnap.conf` (`maxSnapshots`, `minHoursBetweenSnapshots`, `skipAutosnap`). `xorg-xhost` optdep is vestigial (25.x imports the Wayland env itself). Alternative stack: `snapper` + `snap-pac` + `btrfs-assistant` (btrfs only).

## 10 Apps & gaming

- Arch `wine`/`wine-staging` ≥10.8-2 are new-WoW64: **no `lib32-*` deps**, `WINEARCH=win32` gone; the old 5-tier lib32 lists are dead. `wine` is the recommended branch, `wine-staging` experimental. `wine-cachyos-opt` (`/opt`) is CachyOS's runner for Lutris/Heroic; `wine-cachyos` as *system* wine is discouraged by CachyOS.
- `proton-cachyos-slr` (Steam-Linux-Runtime build; the one for EAC/BattlEye) installs to `/usr/share/steam/compatibilitytools.d/`; CachyOS: keep Valve Proton as the global default. `umu-launcher` runs Proton outside Steam (Lutris/Heroic/Faugus backend). `gamescope` from `[cachyos-v3]` is a patched build; `lib32-gamescope` only exists there. `--mangoapp` instead of `mangohud` inside gamescope; `setcap CAP_SYS_NICE` on gamescope breaks the Steam overlay. `LD_PRELOAD=""` fixes the recorder/gamescope stutter but kills the overlay.
- NTSync is default-on in Valve Proton ≥11, Proton-CachyOS, GE ≥10-10; `PROTON_NO_NTSYNC=1` is the only knob; `PROTON_USE_NTSYNC`, `PROTON_NO_ESYNC` obsolete; `PROTON_ENABLE_WAYLAND` is GE/CachyOS/EM only (experimental); `DXVK_ASYNC` never existed upstream; `mesa_glthread` is radeonsi's default; every useful `RADV_PERFTEST` flag is default on RDNA4; `PROTON_USE_EAC_LINUX` undocumented. ntsync is auto-loaded three ways (cachyos-settings, `ntsync-autoload` via wine, proton-cachyos-slr).
- In `[cachyos]`, not AUR: `protonup-qt`, `brave-bin`, `zen-browser-bin` (pulls a second `ffmpeg4.4`), `vesktop`, `onlyoffice-bin`, `heroic-games-launcher-bin`, `localsend`, `coolercontrol`, `umu-launcher`, `faugus-launcher`, `mangojuice`, `obs-vkcapture`. Real AUR: `code-marketplace`, `code-features` (needs an `org.freedesktop.secrets` provider: kwallet/gnome-keyring/keepassxc), `visual-studio-code-bin` (conflicts `code`), `rustdesk-bin`, `lm-studio-bin`, `timeshift-autosnap`, `ttf-ms-fonts`.
- `obs-studio`: VA-API encode is inside mesa; virtual camera needs no `v4l2loopback-dkms` on `linux-cachyos*` (kernel provides `V4L2LOOPBACK-MODULE`). `keepassxc` is still Qt5. `code` pulls `electron42` (~250 MB). `docker` group = passwordless root.
- ROCm: upstream lists RX 9070 (`gfx1201`) as supported; Arch is not a supported ROCm distro (community builds); `rocm-hip-runtime` is the intended entry package (pulls `rocminfo`, `rocm-llvm`); `ollama-rocm` pulls hipblas/rocblas (gfx1201 coverage in Arch's build unverified) → `ollama-vulkan`; LM Studio uses its bundled Vulkan llama.cpp; Arch `whisper-cpp` is CPU-only (no Vulkan/HIP ggml backend).

## 12 HDD gaming

- **Schedulers**: `bfq` budgets I/O per process (background writes can't starve a game's reads) — right for the disk that holds `/` and `/home`. On a disk that only streams game assets, bfq's fairness costs throughput: `low_latency=0` stops it throttling a heavy reader to "play fair", `slice_idle=0` stops the head pausing between a process's requests. `mq-deadline` has neither concept (reads before writes, 500 ms read deadline) — simplest for a pure games disk. Its `read_expire=500`, `front_merges=1` and the `nr_requests=128` queue depth are kernel defaults (Documentation/block/deadline-iosched.rst; `BLKDEV_DEFAULT_RQ`), so writing them is a no-op.
- **`read_ahead_kb`**: the one knob with a real effect on sequential `.pak` streaming from a HDD; 2 MB on a mixed OS disk (bigger starts hurting small-file latency), 4–6 MB on a games-only disk.
- **`e4defrag`** (e2fsprogs) works on a mounted ext4; Steam writes chunks in parallel, so fresh installs on a HDD are fragmented. Pointless on SSD/btrfs (btrfs has `btrfs filesystem defragment`, but it breaks snapshot reflinks).
- **THP**: the CachyOS kernel defaults to `always` with `khugepaged/max_ptes_none=409` and `defrag=defer+madvise` (cachyos-settings) precisely so `always` doesn't bloat or stall; `madvise` is a troubleshooting fallback if asset loads still stutter, not a default.
- **Not worth it** (from an AI-generated "HDD gaming" summary): `commit=300` (data is still flushed at `vm.dirty_expire_centisecs`, only the metadata-loss window grows), `vm.swappiness=30` (overridden to 150 by `30-zram.rules`, and low swappiness is backwards with zram), `vfs_cache_pressure=10` (fine, 20 in the guide; never 0), `VKD3D_SHADER_CACHE_PATH=/tmp DXVK_STATE_CACHE_PATH=/tmp` (tmpfs doesn't speed up compilation — it's CPU-bound — and the cache is wiped every reboot; `DXVK_STATE_CACHE_*` is a dead DXVK 1.x variable), `gamemoded` (conflicts with ananicy-cpp; `game-performance` instead), `PROTON_USE_EAC_LINUX=1` (undocumented in Valve/GE/CachyOS READMEs), per-game UE/CS2 flags (`-notexturestreaming`, `+cl_forcepreload` — game config, not system tuning; `-notexturestreaming` needs the whole level's textures to fit in VRAM).

## Auditing an existing install

```bash
journalctl -b -k --no-pager | grep -iE "invalid for parameter|Unknown kernel command line"   # rejected cmdline params
sysctl vm.swappiness vm.dirty_bytes vm.dirty_ratio vm.max_map_count; grep -r . /etc/sysctl.d/   # runtime vs files
awk '$3=="ext4"{print $2, $4, $6}' /etc/fstab                                                # passno 0 / missing errors=remount-ro on data partitions
pacman -Qq | grep -E '^(xf86-video-|xorg-xhost|plymouth$)'                                   # X11 leftovers; plymouth without its hook
ls ~/.config/xdg-desktop-portal/                                                             # user portals.conf overriding the compositor's
ps -eLo rtprio,policy,comm | grep data-loop                                                  # TS = PipeWire has no realtime priority
pacman -Qtdq; pacman -Qqm                                                                    # orphans; foreign packages (AUR -bin duplicates of [cachyos] packages)
command -v hdparm man less >/dev/null || echo "missing tools that rules/docs expect"
```

Findings on the reference machine: `ahci.mobile_lpm_policy=max_performance` rejected; `vm.swappiness=30` in sysctl.d overridden to 150; dead `vm.dirty_bytes = 0` lines; `/home` and `/mnt/Games` with `passno 0` and no `errors=remount-ro`; `xf86-video-amdgpu`, `xf86-video-ati`, `xorg-xhost`, `plymouth` unused; a user `portals.conf` routing the file chooser to `wlr`; PipeWire without RT; AUR `coolercontrol-bin` duplicating `[cachyos]/coolercontrol`; `PROTON_USE_NTSYNC=1` / `FSR4_UPGRADE=1` in launch options.

## Things older guides get wrong (summary)

fstab: `nobh`, `delalloc`, `dioread_nolock`, `journal_checksum`, `data=ordered`, `barrier=1`, btrfs `ssd`/`space_cache=v2`/`discard=async` are removed or default; `user` ⇒ `noexec`; `comment=x-gvfs-show` is a bug; `data=writeback` can't be applied to `/` from fstab; `subvolid=` breaks Timeshift. Cmdline: `ahci.mobile_lpm_policy=max_performance` rejected; `split_lock_detect` Intel-only; `ppfeaturemask=0xffffffff` unstable; `dcdebugmask=0x10` laptop-only; `max_cstate=1` hurts Zen boost. sysctl: `vm.max_map_count=262144` lowers the default; `kernel.sched_*` gone; swappiness overridden by udev; `dirty_ratio`/`dirty_bytes` exclusive. Packages: `p7zip`→`7zip`, `exfat-utils`→`exfatprogs`, `ntfs-3g`→`ntfs3`, `libva-mesa-driver`/`mesa-vdpau`→`mesa`, `gstreamer-vaapi`→`gst-plugin-va`, `amdvlk` gone, `nvidia(-dkms)`→`nvidia-open(-dkms)`, `kwrite`→`kate`, `evince`/`totem`/`cheese`→`papers`/`showtime`/`snapshot`, `cantarell-fonts`→`adwaita-fonts`, `pavucontrol-qt` is LXQt's, `paru` is a repo binary, many "AUR" packages are in `[cachyos]`. Wine: no lib32 tiers. Proton: `PROTON_USE_NTSYNC`, `PROTON_NO_ESYNC`, `DXVK_ASYNC`, `mesa_glthread`, `RADV_PERFTEST` dead. Services: `cronie`, `acpid`, `avahi-daemon` unnecessary/conflicting; `gamemode` vs `ananicy-cpp`. Order: remove the old kernel after the new one boots; snapshot before apps. LazyVim: `tree-sitter-cli`, not pynvim/nodejs. Timeshift: `--tags O`, `--skip-grub`, no live ISO has it.
