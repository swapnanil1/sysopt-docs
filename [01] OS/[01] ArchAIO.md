# Arch Linux Configuration Guide

Welcome to the Arch Linux Configuration Guide! This comprehensive guide is divided into multiple sections to help you set up and optimize your Arch Linux environment.

**Note:** Throughout this guide, replace `<your_username>` with your actual username. When you see `sudo vim <file>`, you can use any text editor you prefer (e.g., `sudo nano <file>`).

## Table of Contents (Conceptual for future multi-file structure)

1.  [Core System Setup](#core-system-setup)
2.  [Shell Configuration & AUR Helper](#shell-configuration--aur-helper)
3.  [Hardware Drivers & Setup](#hardware-drivers--setup)
4.  [Desktop Environment & Essential Applications](#desktop-environment--essential-applications)
5.  [System Optimization & Tuning](#system-optimization--tuning)
6.  [Linux Gaming Setup](#linux-gaming-setup)
7.  [Advanced & Specific Use Cases](#advanced--specific-use-cases)
8.  [System Backup with Timeshift](#system-backup-with-timeshift)

---

## 1. Core System Setup

This section covers the absolute essentials to get your Arch Linux system functional and optimized.

### 1.1. Connect to the Internet

If you are using a desktop environment, it likely has built-in Wi-Fi management tools. Alternatively, connect via Ethernet. For command-line management:

- **NetworkManager (Recommended for most users):**

  ```bash
  sudo pacman -S --needed networkmanager
  sudo systemctl enable --now NetworkManager.service
  # To connect via CLI (use 'nmcli device wifi list' to see available networks)
  # nmcli device wifi connect "YourSSID" password "YourPassword"
  ```

  NetworkManager also provides `nmtui` (a text user interface).

- **iwd (iNet Wireless Daemon - lightweight alternative):**
  ```bash
  sudo pacman -S --needed iwd
  sudo systemctl enable --now iwd.service
  # To connect via CLI (use 'iwctl device list', 'iwctl station <device> scan', 'iwctl station <device> get-networks', 'iwctl station <device> connect "YourSSID"')
  # Example:
  # iwctl station wlan0 connect "YourSSID" --passphrase "YourPassword"
  ```

For more tools that might be useful with NetworkManager (e.g., VPN support):

```bash
sudo pacman -S --needed networkmanager-openvpn networkmanager-pptp networkmanager-vpnc bind
```

### 1.2. Optimize Arch Linux Mirrors

Faster mirrors mean faster package downloads.

```bash
sudo pacman -S --needed reflector
sudo reflector --verbose --latest 8 --download-timeout 16 --country 'India,Bangladesh' --sort rate --protocol https,http --save /etc/pacman.d/mirrorlist
```

**Note:** You can change `'India,Bangladesh'` to your country or nearby countries for best results. Run this command periodically to keep your mirrorlist fresh.

### 1.3. Faster & Secure Internet using DNS

Configure `systemd-resolved` for faster DNS lookups, DNS-over-TLS, and caching.

1.  **Edit the configuration file:**

    ```bash
    sudo vim /etc/systemd/resolved.conf
    ```

2.  **Paste or uncomment and modify the following lines:**

    ```ini
    [Resolve]
    DNS=9.9.9.9#quad9
    FallbackDNS=149.112.112.112#quad9
    #DNS=1.1.1.1#cloudflare
    #FallbackDNS=1.0.0.1#cloudflare
    #DNS=8.8.8.8#google
    #FallbackDNS=8.8.4.4#google
    DNSOverTLS=yes # if using dot/doh on the network/router level can consider switching it to no.
    DNSStubListener=yes
    DNSSEC=no # Change to 'yes' for increased security (may slightly impact speed)
    ReadEtcHosts=yes
    MulticastDNS=no
    LLMNR=no
    Cache=yes
    #CacheSize=10000 # Uncomment and adjust if needed, default is usually fine
    ```

3.  **Enable and start the service:**

    ```bash
    sudo systemctl enable --now systemd-resolved.service
    ```

4.  **Ensure NetworkManager (if used) uses systemd-resolved:**
    Create or edit `/etc/NetworkManager/conf.d/dns.conf`:

    ```bash
    sudo mkdir -p /etc/NetworkManager/conf.d/
    sudo vim /etc/NetworkManager/conf.d/dns.conf
    ```

    Add:

    ```ini
    [main]
    dns=systemd-resolved
    ```

    Then restart NetworkManager: `sudo systemctl restart NetworkManager`.
    Alternatively, ensure `/etc/resolv.conf` is a symlink to `systemd-resolved`'s stub resolver:

    ```bash
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    ```

5.  **Flush DNS cache (if needed):**

    ```bash
    sudo resolvectl flush-caches
    ```

6.  **Check Secure DNS status (optional):**
    ```bash
    dig +short txt qnamemintest.internet.nl
    ```
    (You might need to install `bind` tools for `dig`: `sudo pacman -S --needed bind`)

### 1.4. Automatic Package Cache Cleanup

Prevent your package cache from growing indefinitely.

1.  **Install `pacman-contrib` for the `paccache` utility:**

    ```bash
    sudo pacman -S --needed pacman-contrib
    ```

2.  **Create the hooks directory:**

    ```bash
    sudo mkdir -p /etc/pacman.d/hooks
    ```

3.  **Create the hook file:**

    ```bash
    sudo vim /etc/pacman.d/hooks/clean_package_cache.hook
    ```

4.  **Paste the following content:**

    ```ini
    [Trigger]
    Operation = Upgrade
    Operation = Install
    Operation = Remove
    Type = Package
    Target = *

    [Action]
    Description = Cleaning pacman cache (keeping last 2 versions)...
    When = PostTransaction
    Exec = /usr/bin/paccache -rk2
    ```

    This hook will keep the current and one previous version of each package in the cache.

### 1.5. Essential System Packages & Services

Install core components and general utilities.

- **Core System Components:**

  ```bash
  sudo pacman -S --needed dkms dbus ufw timeshift
  ```

  (_`timeshift` is for backups, covered later_)

- **General Utilities and Tools:**

  ```bash
  sudo pacman -S --needed jshon expac git wget acpid avahi net-tools xdg-user-dirs cronie vim openssh htop smartmontools xdg-utils
  ```

  (_`iwd` was mentioned for internet, include here if you opted for it over NetworkManager_)

- **Enable Common System Services:**

  ```bash
  sudo systemctl enable cronie.service
  sudo systemctl enable ufw.service # Firewall
  sudo systemctl enable acpid.service
  sudo systemctl enable avahi-daemon.service
  sudo systemctl enable systemd-timesyncd.service # Time synchronization
  # Optional: Enable fstrim.timer for SSDs if not using 'discard=async' in fstab
  # sudo systemctl enable fstrim.timer
  ```

- **Set Basic Firewall Defaults (UFW):**
  ```bash
  sudo ufw enable
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  # sudo ufw status verbose # To check status
  ```
  **Important:** If you SSH into this machine, remember to allow SSH: `sudo ufw allow ssh` or `sudo ufw allow 22/tcp`.

### 1.6. Archive and File System Utilities

- **Compression Utilities:**

  ```bash
  sudo pacman -S --needed p7zip unrar unzip unace xz rsync zip unarj lrzip lha cpio arj
  ```

- **File System Utilities:**
  ```bash
  sudo pacman -S --needed nfs-utils cifs-utils ntfs-3g exfat-utils gvfs udisks2
  ```
  (_`gvfs` and `udisks2` are particularly useful for desktop environments for auto-mounting drives._)

### 1.7. Multimedia Codecs

For broad multimedia playback support:

```bash
sudo pacman -S --needed gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gstreamer-vaapi x265 x264 lame
```

---

## 2. Shell Configuration & AUR Helper

Customize your shell and enable access to the Arch User Repository (AUR).

### 2.1. Switch to Other Shells (Example: Fish)

If you prefer a shell other than Bash:

```bash
# Example: Fish (Friendly Interactive Shell)
sudo pacman -S --needed fish ttf-jetbrains-mono-nerd # Nerd Font for nice glyphs
sudo chsh -s /usr/bin/fish <your_username>
# You will need to reboot or log out and log back in for the change to take effect.
# reboot
```

### 2.2. Install `paru` (AUR Helper)

`paru` allows you to easily install packages from the AUR.

```bash
# Ensure base-devel and git are installed (usually are, but good check)
sudo pacman -S --needed base-devel git

# Clone and build paru
mkdir -p ~/repos # Or any other directory you prefer for building packages
cd ~/repos
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si
# '-s' installs dependencies, '-i' installs the package after building
# '-c' can be added (makepkg -sic) to clean up build files afterwards

cd ~ # Go back to home directory
```

**Tips for `paru`:**
Edit `/etc/paru.conf` (e.g., `sudo vim /etc/paru.conf`):

1.  Uncomment `SkipReview` to skip reviewing PKGBUILDs for every installation (like `yay`). Use with caution.
2.  Uncomment `CleanAfter` to remove untracked files (build dependencies) after installation.

### 2.3. Configure Shell Aliases (`.bashrc`, `.zshrc`, `config.fish`)

Add useful aliases to your shell's configuration file.

- For **Bash** (`~/.bashrc`):
- For **Zsh** (`~/.zshrc`):
- For **Fish** (`~/.config/fish/config.fish`):

Example aliases (syntax might vary slightly between shells, Fish uses `alias ls "eza -al --color=always --group-directories-first"`):

```bash
# In .bashrc or .zshrc
alias ls='eza -al --color=always --group-directories-first' # If eza is installed (see Terminal Setup)
alias la='eza -a --color=always --group-directories-first'
alias ll='eza -l --color=always --group-directories-first'
alias pi='sudo pacman -S'
alias paru='paru --skipreview --removemake' # Example custom paru alias
alias pr='sudo pacman -R'
alias prs='sudo pacman -Rns' # Note: original had prr, Rns is more common
alias vim='nvim' # If Neovim is installed
alias update='sudo pacman -Syu && paru -Sua --skipreview --removemake'
```

After editing, source the file (e.g., `source ~/.bashrc`) or open a new terminal.

---

## 3. Hardware Drivers & Setup

Ensure your hardware components are working correctly.

### 3.1. Sound System Setup (PipeWire)

PipeWire is the modern standard for audio and video handling on Linux.

1.  **Install PipeWire and related packages:**

    ```bash
    sudo pacman -S --needed alsa-utils pipewire pipewire-pulse pipewire-jack wireplumber realtime-privileges
    ```

2.  **Improve PipeWire performance (mitigates glitches/cut-outs):**
    Add your user to the `realtime` group:

    ```bash
    sudo gpasswd -a <your_username> realtime
    ```

    A reboot or logout/login is required for this group change to take effect.

3.  **Sound Control Utilities:**

    - For Qt-based Desktops (e.g., KDE Plasma, LXQt):
      ```bash
      sudo pacman -S --needed pavucontrol-qt
      ```
    - For GTK-based Desktops (e.g., GNOME, XFCE, Cinnamon):
      ```bash
      sudo pacman -S --needed pavucontrol
      ```

4.  **Manage Audio Output Streams with Helvum (Optional):**
    Helvum is a graphical patchbay for PipeWire, useful for complex audio routing. Like two sound devices having same audio stream
    ```bash
    sudo pacman -S --needed helvum
    ```

### 3.2. Fonts Installation (Optional)

Essential for application compatibility and a pleasant visual experience.

```bash
sudo pacman -S --needed ttf-dejavu ttf-liberation noto-fonts ttf-caladea \
ttf-carlito ttf-opensans otf-overpass ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family \
ttf-linux-libertine freetype2 terminus-font ttf-bitstream-vera ttf-droid ttf-fira-mono \
ttf-fira-sans ttf-freefont ttf-inconsolata libertinus-font \
adobe-source-sans-fonts adobe-source-serif-fonts adobe-source-code-pro-fonts \
cantarell-fonts opendesktop-fonts
# ttf-jetbrains-mono-nerd was installed with Fish, good for terminals
```

Consider `noto-fonts-cjk` for East Asian languages and `noto-fonts-emoji` for emoji support.

### 3.3. Input Device Drivers (Xorg i3, cinnamon)

Install necessary drivers for mice, touchpads, etc., primarily for Xorg sessions. Wayland often handles this differently.

- **Common Input Drivers:**

  ```bash
  sudo pacman -S --needed xf86-input-libinput # Modern general-purpose driver
  # xf86-input-synaptics # For older Synaptics touchpads, libinput is usually preferred
  # xf86-input-evdev # Generic event-based driver, often a fallback
  ```

- **Additional Driver for Virtual Machines:**
  ```bash
  # Required if Arch Linux is installed inside a virtual machine (e.g., VirtualBox, VMware)
  sudo pacman -S --needed xf86-input-vmmouse
  ```

### 3.4. Wi-Fi Connection Setup (Especially for Laptops)

If NetworkManager or `iwd` (from Core Setup) isn't managing Wi-Fi, or for more manual control:

```bash
sudo pacman -S --needed wireless_tools wpa_supplicant ifplugd dialog
```

These are often pulled in as dependencies by NetworkManager or `iwd` but can be installed explicitly.

### 3.5. Bluetooth Support

Enable Bluetooth functionality.

1.  **Install Bluetooth packages:**

    ```bash
    sudo pacman -S --needed bluez bluez-utils
    ```

2.  **Enable the Bluetooth service:**
    ```bash
    sudo systemctl enable --now bluetooth.service
    ```
    You might need a graphical Bluetooth manager depending on your desktop environment (e.g., `blueman` or DE-integrated tools).

---

## 4. Desktop Environment & Essential Applications

Set up your graphical environment and install common applications.

### 4.1. Terminal, Text Editor, and Development Tools

- **Alacritty (Fast Terminal Emulator) & Essential CLI Tools:**

  ```bash
  sudo pacman -S --needed alacritty eza fd ripgrep # eza is a modern ls replacement
  ```

- **Set Alacritty Theme (Optional):**

  ```bash
  mkdir -p ~/.config/alacritty/themes
  git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes
  ```

  You'll need to edit `~/.config/alacritty/alacritty.yml` to use a theme. Refer to Alacritty documentation.

- **Neovim (Text Editor) & LazyVim (Preconfigured Setup):**

  ```bash
  sudo pacman -S --needed neovim python-pynvim nodejs npm # nodejs/npm for some LSP/plugins
  ```

  **To set up LazyVim:**

  1.  Backup existing Neovim configuration (if any):
      ```bash
      mv ~/.config/nvim{,.bak}
      mv ~/.local/share/nvim{,.bak}
      mv ~/.local/state/nvim{,.bak}
      mv ~/.cache/nvim{,.bak}
      ```
  2.  Clone LazyVim starter:
      ```bash
      git clone https://github.com/LazyVim/starter ~/.config/nvim
      rm -rf ~/.config/nvim/.git # Remove starter's git history
      ```
  3.  Run Neovim to initialize:
      ```bash
      nvim
      ```

- **Code - OSS (VSCode open-source build with Microsoft Marketplace):**
  ```bash
  paru -S --needed code code-features code-marketplace
  ```

### 4.2. Web Browsers

Choose your preferred browser(s). `paru` can install from official repos or AUR.

```bash
# Example: Firefox (Official Repo), Brave (AUR), Zen Browser (AUR)
paru -S --needed firefox brave-bin zen-browser-bin
```

### 4.3. Other Common Applications

```bash
paru -S --needed vesktop # Discord client
paru -S --needed telegram-desktop keepassxc mpv qbittorrent bleachbit onlyoffice-bin
```

Okay, I understand! You want a more granular approach to installing KDE Plasma, starting with a genuinely minimal but functional desktop, and then adding optional components based on use-case (laptop features, Flatpak support, etc.). This is a great way to avoid bloat and tailor the installation.

Here's the revised section for KDE Plasma 6, incorporating your suggestions and a more structured approach:

---

### 4.4. Desktop Environments (Optional)

Install a desktop environment if you haven't already. Choose **one**.

- **KDE Plasma 6:**

  KDE Plasma is a feature-rich and highly customizable desktop environment. You can start with a minimal setup and add components as needed.

  1.  **Minimal Core KDE Plasma Desktop:**
      This command installs the essential components for a functional Plasma desktop, including the desktop shell, login manager, a terminal, file manager, network and audio management, power management, and basic theming.

      ```bash
      sudo pacman -S --needed plasma-desktop sddm konsole dolphin \
      breeze-gtk kde-gtk-config kscreen kwallet-pam plasma-nm plasma-pa \
      powerdevil sddm-kcm xdg-desktop-portal-kde \
      ocean-sound-theme plasma-workspace-wallpapers spectacle plasma-systemmonitor
      ```

      - `plasma-desktop`: Core desktop environment.
      - `sddm`: Recommended display manager for Plasma.
      - `konsole`: Default terminal emulator.
      - `dolphin`: Default file manager.
      - `breeze-gtk`, `kde-gtk-config`: For GTK application theming consistency.
      - `kscreen`: Display configuration.
      - `kwallet-pam`: KWallet PAM integration for automatic unlocking.
      - `plasma-nm`: NetworkManager applet.
      - `plasma-pa`: PipeWire/PulseAudio volume applet.
      - `powerdevil`: Power management services.
      - `sddm-kcm`: SDDM configuration module in System Settings.
      - `xdg-desktop-portal-kde`: Essential for integration with sandboxed apps (like Flatpaks).
      - `ocean-sound-theme`, `plasma-workspace-wallpapers`: Basic sounds and wallpapers.
      - `spectacle`: Screenshot utility.
      - `plasma-systemmonitor`: System activity monitor.

      After installation, enable the display manager:

      ```bash
      sudo systemctl enable sddm.service
      ```

      You'll need to **reboot** for the changes to take effect and to log into your new Plasma session.

  2.  **Optional Desktop Enhancements & Utilities:**
      These packages add more common Plasma applications and features.

      ```bash
      sudo pacman -S --needed ark # Archiving tool
      sudo pacman -S --needed kwrite # Simple text editor (or 'kate' for more features)
      sudo pacman -S --needed kdeplasma-addons # Various widgets and addons (e.g., weather, dictionary)
      sudo pacman -S --needed kinfocenter # System information center
      sudo pacman -S --needed plasma-browser-integration # Better browser integration
      sudo pacman -S --needed plasma-disks # Disk health monitoring and management applet
      sudo pacman -S --needed plasma-firewall # GUI for UFW or firewalld
      sudo pacman -S --needed plasma-vault # Encrypted vaults
      sudo pacman -S --needed drkonqi # Crash report assistant
      # sudo pacman -S --needed plasma-welcome # Welcome screen for new users
      # sudo pacman -S --needed ksshaskpass # GUI for SSH key passphrases
      # sudo pacman -S --needed print-manager # For managing printers
      ```

  3.  **For Flatpak Users:**
      If you plan to use Flatpaks, install `flatpak` itself and integration tools for Plasma. `discover` is Plasma's software center, which can manage Flatpaks.

      ```bash
      sudo pacman -S --needed flatpak discover flatpak-kcm
      ```

      - `flatpak`: The Flatpak runtime.
      - `discover`: Plasma's software center (can handle Flatpaks, packages from repos).
      - `flatpak-kcm`: System Settings module to manage Flatpak permissions.

  4.  **For Laptop Users (Additional Hardware Support):**
      These packages are useful for laptop-specific hardware.

      ```bash
      sudo pacman -S --needed bluedevil # Bluetooth integration for Plasma
      # sudo pacman -S --needed plasma-thunderbolt # Thunderbolt device management
      # sudo pacman -S --needed wacomtablet # KCM for Wacom tablet configuration (libwacom is a dependency)
      ```

  5.  **Optional: Theming for GRUB Bootloader & Plymouth Splash Screen:**
      If you use GRUB as your bootloader and Plymouth for a graphical boot splash, you can install Breeze themes for them. (Note: If using `systemd-boot`, so this might not apply to your setup but is useful for a general guide).

      ```bash
      # Ensure plymouth is installed if you intend to use it: sudo pacman -S --needed plymouth
      # Then install themes:
      # sudo pacman -S --needed breeze-grub breeze-plymouth plymouth-kcm
      ```

      You would then need to configure GRUB and Plymouth accordingly (e.g., adding `plymouth` to `HOOKS` in `mkinitcpio.conf` and regenerating initramfs, and setting theme in GRUB config).

  6.  **Optional: Post-install KDE apps and themes:**

      ```bash
      sudo pacman -S --needed packagekit-qt6 okular kate gwenview spectacle kalk kwalletmanager kdeconnect sshfs plasma-systemmonitor kfind kolourpaint kdevelop kamoso krita kdenlive mediainfo
      sudo pacman -S --needed materia-kde materia-gtk-theme capitaine-cursors fcitx5-breeze kvantum
      ```

This breakdown should give users a clear path to a minimal Plasma setup and then allow them to easily add the specific functionality they require.

- **GNOME:**

  ```bash
  sudo pacman -S --needed gnome gdm
  sudo systemctl enable gdm.service # Login manager
  # reboot
  ```

  **GNOME apps, extensions, and themes:**

  ```bash
  sudo pacman -S --needed gnome-text-editor gnome-tweaks gnome-calculator gnome-calendar gnome-photos gnome-sound-recorder gnome-weather gnome-system-monitor gparted gnome-disk-utility
  sudo pacman -S --needed gnome-shell-extensions # Provides a base set
  # For more extensions like appindicator, arc-menu, dash-to-panel, install gnome-shell-extension-manager and browse online
  # paru -S gnome-shell-extension-appindicator gnome-shell-extension-arc-menu-git gnome-shell-extension-dash-to-panel-git
  sudo pacman -S --needed arc-gtk-theme arc-icon-theme papirus-icon-theme # arc-solid-gtk-theme is part of arc-gtk-theme
  ```

- **Cinnamon:**
  ```bash
  sudo pacman -S --needed cinnamon lightdm lightdm-gtk-greeter # Or another login manager like gdm/sddm
  sudo systemctl enable lightdm.service
  # reboot
  ```
  **Cinnamon apps & themes:**
  ```bash
  # Using paru as some might be AUR packages or have AUR alternatives
  paru -S --needed xed xreader galculator gnome-screenshot gparted webkit2gtk gnome-terminal file-roller celluloid drawing gufw warpinator mint-themes mint-y-icons
  paru -S --needed nemo-audio-tab nemo-emblems nemo-fileroller nemo-image-converter nemo-pastebin nemo-preview nemo-python nemo-seahorse nemo-share gvfs-mtp
  paru -S --needed pix xviewer webapp-manager mint-backgrounds
  ```

---

## 5. System Optimization & Tuning

Fine-tune your system for better performance and usability.

### 5.1. Optional: Remap Keys on Keyboard

- **Method 1 (CLI): Keyd**
  Lightweight and powerful.

  1.  Install:
      ```bash
      sudo pacman -S --needed keyd
      sudo systemctl enable --now keyd.service
      ```
  2.  Edit config file (`sudo vim /etc/keyd/default.conf`). Example:

      ```ini
      [ids]
      * # Apply to all keyboards

      [main]
      # Example: Swap Left Alt and Left Meta (Super/Windows key)
      leftmeta = leftalt
      leftalt = leftmeta
      # Example: Disable F9 key
      # f9 = noop
      ```

  3.  **Important `keyd` commands:**
      - `sudo keyd monitor`: Test key presses and identify key names.
      - `sudo keyd reload`: Apply changes without rebooting.
      - `sudo journalctl -eu keyd -f`: View logs for troubleshooting.

- **Method 2 (GUI): Input Remapper**
  User-friendly graphical interface.
  ```bash
  paru -S --needed input-remapper-git
  sudo systemctl enable --now input-remapper.service
  # sudo systemctl restart input-remapper # If already enabled and you made changes
  ```
  Launch `input-remapper-gtk` from your application menu to configure.

### 5.2. Format and Grant Permissions to Additional Hard Drives

For new or repurposed drives. **WARNING: `mkfs` will erase all data on the specified partition.**

1.  **Install filesystem tools (if not already present):**
    ```bash
    sudo pacman -S --needed e2fsprogs # For ext4
    # sudo pacman -S --needed btrfs-progs # For BTRFS
    # sudo pacman -S --needed xfsprogs # For XFS
    ```
2.  **Identify the drive/partition:**
    ```bash
    lsblk -f
    ```
    Look for your target device, e.g., `/dev/sda1`, `/dev/sdb`, etc.
3.  **Format the partition (Example: ext4 on `/dev/sda1`):**
    ```bash
    # sudo mkfs.ext4 /dev/sda1
    ```
    Replace `/dev/sda1` with your actual partition.
4.  **Label the partition (Optional but recommended):**

    ```bash
    # sudo e2label /dev/sda1 MyDataDrive
    ```

5.  **Create a mount point:**

    ```bash
    sudo mkdir /mnt/MyDataDrive
    ```

6.  **Mount the drive temporarily:**

    ```bash
    # sudo mount /dev/sda1 /mnt/MyDataDrive
    ```

7.  **Change ownership to your user:**

    ```bash
    sudo chown -R <your_username>:<your_username> /mnt/MyDataDrive
    ```

8.  **Hide lost+found system folder:**

    ```bash
    echo "lost+found" > .hidden
    ```

9.  **For permanent mounting, add an entry to `/etc/fstab`.** (See next section)

### 5.3. Improve Read/Write Speeds & Auto-Mount (Edit `/etc/fstab`)

**WARNING: Incorrectly editing `/etc/fstab` can render your system unbootable. Proceed with extreme caution. Backup your `/etc/fstab` before editing: `sudo cp /etc/fstab /etc/fstab.bak`**

1.  **Get the UUID of your partition:**
    ```bash
    lsblk -f
    # Or more specifically for a device:
    # sudo blkid /dev/sda1
    ```
2.  **Edit `/etc/fstab`:**
    ```bash
    sudo vim /etc/fstab
    ```
3.  **Add a line for your drive. Examples:**

    - **For an ext4 drive (common):**

      ```
      simple
      # UUID=<your_partition_uuid> /mnt/MyDataDrive ext4 defaults,noatime,rw,user,exec,auto 0 2
      performance
      # UUID=<your_partition_uuid> /mnt/MyDataDrive ext4 defaults,noatime,user,auto,exec,data=writeback,barrier=0,nobh,errors=remount-ro 0 0
      ```

      Replace `<your_partition_uuid>` with the actual UUID and `/mnt/MyDataDrive` with your mount point.

      - `noatime`: Disables writing file access times, can improve performance.
      - `user`: Allows any user to mount/unmount.
      - `exec`: Allows execution of binaries.
      - `auto`: Mounts automatically at boot.
      - The `0 2` at the end are for dump and fsck order.

    - **User's provided BTRFS example (for NVMe):**
      ```
      # /dev/nvme0n1    /mnt/abcdefgh    btrfs   rw,noatime,ssd,discard=async,compress=zstd:3,space_cache=v2 0 0
      # /dev/nvme0n1    /mnt/zxcvedfd    btrfs   rw,noatime,nodatasum,nodatacow,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@ 0 0
      # /dev/nvme0n1pX /mnt/abcdefgh     btrfs   rw,noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,autodefrag 0 0
      # UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx /mnt/MyDataDrive ext4 defaults,noatime,user,auto,exec,data=writeback,barrier=0,nobh,errors=remount-ro,x-gvfs-show 0 0
      ```
      **Note on user's examples:**
      - `discard=async`: Good for SSDs if fstrim.timer is not used.
      - `compress=zstd:3`: BTRFS compression.
      - `nodatasum,nodatacow`: These disable data checksumming and copy-on-write for specific subvolumes/paths, which can increase performance for certain workloads (like virtual machine images or database files) but reduce data integrity features. Use with understanding.
      - `x-gvfs-show`: Makes the mount visible in file managers like Nautilus.

4.  **Test `fstab` changes without rebooting:**
    First unmount the drive if it's currently mounted: `sudo umount /mnt/MyDataDrive`
    Then try to mount all entries in `fstab`: `sudo mount -a`
    If there are errors, revert your `fstab` changes from the backup.

### 5.4. Enable Active Noise Suppression for Headset Mic

Uses `rnnoise` to filter out background noise from your microphone input.

1.  **Install the LADSPA plugin:**

    ```bash
    sudo pacman -S --needed noise-suppression-for-voice
    ```

2.  **Create PipeWire configuration directory if it doesn't exist:**

    ```bash
    mkdir -p ~/.config/pipewire/pipewire.conf.d/
    ```

3.  **Create a filter configuration file:**

    ```bash
    vim ~/.config/pipewire/pipewire.conf.d/99-input-denoising.conf
    ```

4.  **Paste the following content:**

    ```lua
    context.modules = [
        {   name = libpipewire-module-filter-chain
            args = {
                node.description =  "Noise Canceling Source"
                media.name =  "Noise Canceling Source"
                filter.graph = {
                    nodes = [
                        {
                            type = ladspa
                            name = rnnoise
                            plugin = /usr/lib/ladspa/librnnoise_ladspa.so
                            label = noise_suppressor_mono
                            control = {
                                # Adjust these values as needed
                                "VAD Threshold (%)" = 50.0
                                "VAD Grace Period (ms)" = 200
                                "Retroactive VAD Grace (ms)" = 0
                            }
                        }
                    ]
                }
                capture.props = {
                    node.name = "capture.rnnoise_source"
                    node.passive = true
                    audio.rate = 48000 # Match your microphone's typical sample rate
                }
                playback.props = { # This creates the virtual source
                    node.name = "rnnoise_source"
                    media.class = Audio/Source
                    audio.rate = 48000
                }
            }
        }
    ]
    ```

5.  **Restart PipeWire services or reboot:**
    ```bash
    systemctl --user restart pipewire pipewire-pulse wireplumber
    ```
    After restarting, you should see a new input source named "Noise Canceling Source" in your sound settings. Select this as your input device in applications.

### 5.5. UniClip: Sync Clipboards Across Mac and Linux PCs (Optional)

1.  **Installation:**

    - Go to the [UniClip GitHub releases page](https://github.com/quackduck/uniclip/releases).
    - Download the binary for your architecture (e.g., `uniclip_xxx_linux_x86_64.tar.gz`).
    - Extract and install:
      ```bash
      # Example for a downloaded tar.gz file
      # tar -xzf uniclip_*.tar.gz
      # cd uniclip_*/
      # sudo cp uniclip /usr/local/bin/ # Or /usr/bin/
      ```

2.  **Firewall Configuration (using `ufw`):**
    UniClip uses a random port between 30000 and 60000.

    - Run `uniclip` on the "host" device. It will display its IP and the port it's using.
    - On **each** device that needs to connect, allow incoming connections _from_ the other devices' IPs to this port range.
      Example: If Host A is `192.168.1.10` and Host B is `192.168.1.11`.
      - On Host A, to allow connections from Host B:
        ```bash
        sudo ufw allow from 192.168.1.11 proto tcp to any port 30000:60000
        ```
      - On Host B, to allow connections from Host A:
        ```bash
        sudo ufw allow from 192.168.1.10 proto tcp to any port 30000:60000
        ```
    - **Security Note:** This opens a wide port range from specific IPs. If UniClip supports static ports in the future, narrow this rule.

3.  **Usage:**
    - Run `uniclip` on the first device (server). It will print its IP and port.
    - Run `uniclip <server_ip>:<port>` on other devices to connect.

---

## 6. Linux Gaming Setup

Optimize your system for gaming.

### 6.1. Install Steam

```bash
sudo pacman -S --needed steam
```

Ensure your system is 32-bit compatible (`multilib` repository enabled in `/etc/pacman.conf`). Steam requires many 32-bit libraries.

### 6.2. Graphics Drivers

- **AMD Graphics Driver (Mesa):**

  ```bash
  sudo pacman -S --needed mesa lib32-mesa libva-mesa-driver lib32-libva-mesa-driver \
  mesa-vdpau lib32-mesa-vdpau vulkan-radeon lib32-vulkan-radeon \
  vulkan-icd-loader lib32-vulkan-icd-loader
  # For OpenCL (compute)
  # sudo pacman -S --needed opencl-clover-mesa lib32-opencl-clover-mesa # Older OpenCL
  # sudo pacman -S --needed opencl-rusticl-mesa lib32-opencl-rusticl-mesa # Newer OpenCL (Recommended)
  # sudo pacman -S --needed rocm-opencl-runtime # For ROCm capable cards (usually newer)
  ```

  **Optional for X11 (if not using Wayland primarily):**

  ```bash
  # sudo pacman -S --needed xf86-video-amdgpu
  # xf86-video-ati is for very old cards, amdgpu is for modern ones.
  # Often not needed as Mesa's modesetting driver works well.
  ```

- **NVIDIA Graphics Driver:**
  (This guide primarily focuses on AMD based on user input, but for NVIDIA):
  ```bash
  # For current GPUs:
  # sudo pacman -S --needed nvidia nvidia-utils lib32-nvidia-utils
  # For older GPUs, you might need nvidia-dkms, or specific legacy drivers (e.g., nvidia-470xx-dkms).
  # Also install:
  # sudo pacman -S --needed nvidia-settings
  # For CUDA/OpenCL:
  # sudo pacman -S --needed opencl-nvidia cuda
  ```
  Refer to the Arch Wiki for detailed NVIDIA instructions.

### 6.3. Install Wine & Wine Dependencies

For running Windows applications and games. The following approach prioritizes a minimal installation. Tiers 1, 2, and 3 represent a solid, functional Wine setup. Anything beyond Tier 3 should be considered **optional and only installed if a specific application or game explicitly requires it**, to avoid unnecessary bloat.

- **Tier 1: Core Wine Installation (Essential)**
  These are the fundamental Wine packages.

  ```bash
  sudo pacman -S --needed wine-staging wine-mono wine-gecko winetricks
  ```

  - `wine-staging`: The compatibility layer itself.
  - `wine-mono`: Open-source implementation of .NET Framework for Wine.
  - `wine-gecko`: Open-source implementation of Internet Explorer's Trident engine for Wine.
  - `winetricks`: A helper script to download and install various redistributable runtime libraries.

- **Tier 2: Minimal Wine Base Runtime Dependencies**
  These libraries are crucial for basic Wine functionality as defined by your core needs.

  ```bash
  sudo pacman -S --needed  \
  giflib lib32-giflib \
  gnutls lib32-gnutls \
  v4l-utils lib32-v4l-utils \
  libpulse lib32-libpulse \
  alsa-plugins lib32-alsa-plugins \
  alsa-lib lib32-alsa-lib \
  sqlite lib32-sqlite \
  libxcomposite lib32-libxcomposite \
  libva lib32-libva \
  vulkan-icd-loader lib32-vulkan-icd-loader
  ```

- **Tier 3:Extra BUT Recommended Runtime Dependencies**
  These provide additional common functionalities and are highly recommended for a more complete Wine experience, based on your "extra but absolute" list. but try running games/software with tier 2 only if works avoid this tier.

  ```bash
  sudo pacman -S --needed  \
  gst-plugins-base-libs lib32-gst-plugins-base-libs \
  ocl-icd lib32-ocl-icd \
  gtk3 lib32-gtk3 \
  sdl2-compat lib32-sdl2-compat
   \

  ```

  - **Note on `sdl2-compat`**: This provides SDL 2 API compatibility using an SDL2 backend, matching your `-compat` suffix. If older SDL1.2 is needed directly, see Tier 4.

- **Tier 4: Common Optional Dependencies (Install ONLY If Needed)**
  The packages in this tier are **not considered part of the absolute base**. Install them only if a specific game or application fails and troubleshooting indicates one of these is required. Many common Wine features are covered by Tiers 1-3.

  ```bash
  # For font rendering and common image formats:
  # sudo pacman -S --needed  fontconfig lib32-fontconfig libjpeg-turbo lib32-libjpeg-turbo libpng lib32-libpng libxslt lib32-libxslt

  # For Direct3D 12 to Vulkan translation (if not using Proton's vkd3d-proton):
  # sudo pacman -S --needed  vkd3d lib32-vkd3d

  # For modern SDL1.2 (many old games use this directly):
  # sudo pacman -S --needed  sdl12-compat lib32-sdl12-compat

  # For 3D audio:
  # sudo pacman -S --needed  openal lib32-openal

  # For extended multimedia support (beyond gst-plugins-base-libs):
  # sudo pacman -S --needed  gst-plugins-good lib32-gst-plugins-good

  # For hardware interaction like printing, cameras, scanners (less common for games):
  # sudo pacman -S --needed  cups lib32-cups libgphoto2 lib32-libgphoto2 sane lib32-sane

  # Utilities and libraries for specific game installers or features:
  # sudo pacman -S --needed cabextract innoextract ttf-liberation
  # sudo pacman -S --needed gamemode lib32-gamemode # If you use gamemode
  # sudo pacman -S --needed libldap lib32-libldap # For apps needing LDAP (e.g., some enterprise apps via Wine)
  # sudo pacman -S --needed samba # For NTLM authentication, some older installers
  ```

  **Approach for Tier 4:** Uncomment and install only the specific lines you identify as necessary.

- **Tier 5: Advanced or Highly Specific Dependencies (Avoid Unless Essential)**
  This tier is for packages that are rarely required or are for very niche use cases. Installing these without a clear need contributes to bloat. Always try `winetricks` first for missing Windows components.

  ```bash
  # Example: For very old DOS games not handled by Wine/Lutris's DOSBox integration:
  # sudo pacman -S --needed dosbox

  # Example: For specific console applications within Wine or rare audio needs:
  # sudo pacman -S --needed ncurses lib32-ncurses mpg123 lib32-mpg123

  # Further extensive list (from original "Extras" and "Extreme" lists, use with extreme caution):
  # sudo pacman -S --needed lib32-libnm cups-filters libexif libmikmod libpaper qpdf sdl_net sdl_sound lib32-libxss lib32-nspr lib32-nss lsb-release lsof usbutils xorg-xrandr zenity python-evdev lib32-libxxf86vm lib32-libxml2 lib32-openssl nss-mdns lib32-gstreamer gsm lib32-glu lib32-libsm lib32-libice
  ```

### 6.4. Install Lutris & Dependencies

Lutris helps manage and launch games from various sources.

```bash
sudo pacman -S --needed lutris
# Optional Lutris dependencies for wider compatibility:
sudo pacman -S --needed vulkan-tools python-gobject python-requests python-pillow python-yaml python-setproctitle python-distro psmisc p7zip curl soundfont-fluid # python-evdev already in gaming section
# GObject introspection runtime is usually pulled by python-gobject or gtk3
# sudo pacman -S --needed gobject-introspection gobject-introspection-runtime
```

### 6.5. Install FPS Overlay (MangoHud) & Gamescope

- **MangoHud (FPS & System Monitoring Overlay):**

  ```bash
  sudo pacman -S --needed mangohud lib32-mangohud goverlay # Goverlay is a GUI for MangoHud
  ```

  Usage: Prepend `mangohud` to game launch commands, e.g., `mangohud steam` or in Steam launch options: `mangohud %command%`.

- **Gamescope (Micro-compositor for games, Wayland/X11 nesting):**
  ```bash
  sudo pacman -S --needed gamescope
  # lib32-vulkan-mesa-layers is part of lib32-mesa or specific vulkan drivers
  ```
  Usage: `gamescope -w <width> -h <height> -r <refresh_rate> -- %command%`

### 6.6. Epic Games Launcher (Heroic Games Launcher)

```bash
paru -S --needed heroic-games-launcher-bin
```

### 6.7. Common Game Dependencies & Tools

- **ProtonUp-Qt (Manage Proton-GE, Wine-GE, Luxtorpeda, etc.):**
  ```bash
  paru -S --needed protonup-qt
  ```
- **Microsoft Core Fonts (often needed by games):**
  ```bash
  paru -S --needed ttf-ms-win11-auto # Or ttf-ms-fonts from AUR for older set
  ```
- **GSM Audio Codec (some older games):**
  ```bash
  sudo pacman -S --needed lib32-gsm
  ```

### 6.8. Use Custom Kernel & Wine (Advanced)

For potentially higher performance, but requires more effort.

- **Custom Kernel (e.g., `linux-tkg` , `linux-cachyos`):**

  - Follow instructions from [Frogging-Family/linux-tkg](https://github.com/Frogging-Family/linux-tkg). This involves cloning the repo, configuring, building, and installing the kernel. It's an advanced process.
  - The video link you provided ([A1RM4X](https://youtu.be/QIEyv-Pnh0w?si=xBIZg6HLMzp9aP2X)) might offer a good tutorial.
  - Cachyos kernel can be installed using aur (No compilation required)

- **Custom Wine Builds (e.g., `wine-tkg-git`):**
  - Prebuilt versions can often be found on the [wine-tkg-git GitHub Actions page](https://github.com/Frogging-Family/wine-tkg-git/actions/workflows/wine-arch.yml) (requires GitHub login).
  - Alternatively, build it yourself using the `wine-tkg-git` PKGBUILDs.(Better Approach)

### 6.9. Optimize Game Performance (System Tweaks)

- **Increase `vm.max_map_count` (for some games like CS2, Elden Ring):**
  Create a sysctl configuration file:

  ```bash
  sudo vim /etc/sysctl.d/80-gamecompatibility.conf
  ```

  Add:

  ```
  vm.max_map_count = 16777216
  ```

  Apply immediately: `sudo sysctl --system` or reboot.

- **Mitigate Split Lock (Optional, potential performance gain, slight stability risk):**
  Create a sysctl configuration file:

  ```bash
  sudo vim /etc/sysctl.d/99-splitlock.conf
  ```

  Add:

  ```
  kernel.split_lock_mitigate=0
  ```

  Apply immediately: `sudo sysctl --system` or reboot.

- **Kernel Parameters for Gaming (Advanced):**
  Add these to your bootloader's kernel command line (GRUB: `/etc/default/grub` then `sudo grub-mkconfig -o /boot/grub/grub.cfg`; systemd-boot: edit your loader entry in `/boot/loader/entries/`).
  **WARNING: Test these individually. `mitigations=off` disables CPU security mitigations and can be a security risk.**
  ```
  zswap.enabled=0
  nowatchdog
  mitigations=off # Use with extreme caution and understand the security implications
  amdgpu.ppfeaturemask=0xffffffff # For AMD GPUs, unlocks power play features for overclocking tools
  amdgpu.dcdebugmask=0x400 # Recommended if using Wayland and AMD GPU
  # amdgpu.dcdebugmask=0x10 # Or, for specific AMD GPU debugging
  # split_lock_detect=off # This will completely disable the kernel's split-lock detection mechanism. Might Increase Performance
  ```
  After adding to bootloader config, regenerate initramfs and reboot:
  - If using `mkinitcpio` (default): `sudo mkinitcpio -P`
  - If using `dracut`: `sudo dracut --regenerate-all --force`
    Then reboot.

### 6.10. Using `ananicy-cpp` instead of `gamemode` (Alternative)

Ananicy manages process priorities. `cachyos-ananicy-rules` provides game/app-specific rules.

**Important: This requires adding the CachyOS repositories to your system FIRST.** The process for this is not covered here; you'll need to find instructions for adding CachyOS repos to Arch Linux.

1.  **Once CachyOS repos are added, install:**

    ```bash
    paru -S --needed ananicy-cpp cachyos-ananicy-rules-git power-profiles-daemon cpupower upower cachyos-settings-git
    ```

    (Using `-git` versions for rules and settings as they are often more up-to-date from CachyOS).
    Enable `ananicy-cpp` service: `sudo systemctl enable --now ananicy-cpp.service`

2.  **Trigger game mode via `cachyos-settings` script:**
    In Steam launch options or when launching a game from terminal:

    ```
    game-performance %command%
    # Or for non-Steam games:
    # game-performance /path/to/game_executable
    ```

    `LD_PRELOAD=""` might be needed if you encounter issues: `game-performance LD_PRELOAD="" %command%`

3.  **Ananicy-cpp + Gamemode is NOT recommended** as they perform similar functions and might conflict.

4.  **CPU & PCI Latency Tweaks (if using `ananicy-cpp` ecosystem):**

    - Set CPU governor to performance:
      ```bash
      sudo powerprofilesctl set performance # Requires power-profiles-daemon
      # OR manually:
      # sudo cpupower frequency-set -g performance
      ```
    - Improve PCI latency (cachyos-settings might provide this service):
      ```bash
      # sudo systemctl enable --now pci-latency.service # Check if this service is provided by cachyos-settings
      ```

5.  **Check AMD P-State and CPU Governor (For AMD Ryzen CPUs):**
    - **In BIOS:** Ensure CPPC (Collaborative Processor Performance Control) and Core Performance Boost are enabled. Consider disabling C-States for consistent performance (may increase idle power).
    - Verify P-State status:
      ```bash
      cat /sys/devices/system/cpu/amd_pstate/status # Should be 'active' or 'guided'
      cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver # Should show amd_pstate_epp or similar
      cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference # Should be 'performance' when gaming
      ```

---

## 7. Advanced & Specific Use Cases

### 7.1. Android Debug Bridge (ADB) & Firmware Management (Heimdall)

- **ADB Setup:**

  1.  Install tools:
      ```bash
      sudo pacman -S --needed android-tools android-udev
      ```
  2.  Add user to `adbusers` group (or `adb` group, check `/usr/lib/udev/rules.d/51-android.rules` for the correct group name):
      ```bash
      sudo usermod -aG adbusers <your_username>
      ```
      Reboot or log out/in for group changes to apply.
  3.  **Common ADB commands:**
      ```bash
      adb devices            # List connected devices (authorize on phone if prompted)
      adb reboot bootloader  # Reboot to fastboot/bootloader mode
      adb reboot recovery    # Reboot to recovery mode
      # adb sideload <filename.zip> # Sideload update zip in recovery
      ```

- **Heimdall (for Samsung devices):**
  1.  Install:
      ```bash
      sudo pacman -S --needed heimdall
      ```
  2.  **Common Heimdall commands (run as root or with `sudo`):**
      ```bash
      sudo heimdall print-pit                # Display partition table (device in download mode)
      # sudo heimdall flash --RECOVERY recovery.img --no-reboot # Flash recovery image
      ```

### 7.2. Davinci Resolve (AMD GPU) Prerequisites for Pre-Vega GPUs

For older AMD GPUs (Pre-Vega architecture like Polaris - RX 4xx/5xx series) to work with ROCm for Davinci Resolve.

1.  **Install ROCm components and dependencies:**
    ```bash
    sudo pacman -S --needed libxcrypt-compat rocm-core libarchive xdg-user-dirs patchelf rocm-opencl-runtime
    ```
2.  **Set environment variable:**
    Edit `/etc/environment`:
    ```bash
    sudo vim /etc/environment
    ```
    Add this line:
    ```
    ROC_ENABLE_PRE_VEGA=1
    ```
    Save and exit. A reboot is required for this to take effect system-wide.

### 7.3. Overclocking AMD GPUs with `amdgpu-clocks` (Minimal CLI tool)

**WARNING: Overclocking can lead to instability or damage your hardware if not done carefully. Proceed at your own risk.**

1.  **Installation:**

    ```bash
    git clone https://github.com/sibradzic/amdgpu-clocks ~/repos/amdgpu-clocks # Clone to your preferred dir
    cd ~/repos/amdgpu-clocks
    sudo cp amdgpu-clocks /usr/local/bin/
    sudo cp amdgpu-clocks.service /etc/systemd/system/
    sudo systemctl enable --now amdgpu-clocks.service
    ```

2.  **Configure Custom States:**

    - Find your GPU's PCI address:
      ```bash
      lspci | grep -i vga
      ```
      Look for something like `0000:26:00.0`.
    - Create/edit the config file, replacing `26:00.0` with your GPU's bus ID:
      ```bash
      sudo vim /etc/default/amdgpu-custom-state.pci-0000:26:00.0
      ```
    - Add your custom states. **The following is an EXAMPLE. You MUST find stable values for YOUR card.**

      ```ini
      # Example for an RX 570/580. Values are illustrative.
      # Set custom GPU Core Clock (SCLK) states 6 & 7:
      OD_SCLK:
      # State: Clock (MHz)   Voltage (mV)
      #6:       1300MHz        1050mV
      #7:       1400MHz        1090mV

      # Set custom GPU Memory Clock (MCLK) states 1 & 2:
      OD_MCLK:
      # State: Clock (MHz)   Voltage (mV)
      #1:       1750MHz        750mV
      #2:       1900MHz        900mV # Stock for many RX 500 series is 1750MHz, 2000MHz for some

      # Force specific SCLK states (e.g., only use states 5, 6, 7):
      # FORCE_SCLK: 5 6 7

      # Force a fixed memory state (e.g., always use state 2):
      # FORCE_MCLK: 2

      # Force power limit (in microWatts), e.g., 187W = 187000000
      # FORCE_POWER_CAP: 187000000

      # To enable FORCE_SCLK & FORCE_MCLK, performance level must be manual:
      FORCE_PERF_LEVEL: manual
      ```

    - Start with small increments and test stability thoroughly. You can view current clocks/voltages with `cat /sys/class/drm/card0/device/pp_od_clk_voltage` (replace `card0` if needed).

3.  **Ensure `amdgpu.ppfeaturemask=0xffffffff` kernel parameter is set** (see "Kernel Parameters for Gaming").
4.  Reboot. Then check service status: `systemctl status amdgpu-clocks.service`.

### 7.4. Optional Personal Firmware (User-Specific)

This section is for firmware specific to your hardware.
The packages listed (`linux-firmware-qlogic`, `aic94xx-firmware`, `wd719x-firmware`, `upd72020x-fw`) are for specific, less common hardware. Install them if you know you need them. `linux-firmware` (a base package) usually covers most common hardware.

```bash
# Only install if you have identified a need for these specific firmware packages.
# paru -S --needed linux-firmware-qlogic aic94xx-firmware wd719x-firmware upd72020x-fw
```

---

## 8. System Backup with Timeshift

**Crucial Step:** After configuring your system, take a backup. Timeshift is excellent for system snapshots.

1.  **Launch Timeshift** from your application menu or `sudo timeshift-gtk`.
2.  **Setup Wizard (First Time):**
    - **Snapshot Type:**
      - **Rsync:** Recommended for most users. Backups can be saved to any filesystem (ext4, NTFS, etc.).
      - **Btrfs:** If your root filesystem is Btrfs, this is very efficient. Snapshots are taken on the same Btrfs volume.
    - **Snapshot Location:** Choose a partition for storing backups. **It's highly recommended to use a separate drive/partition for backups.**
    - **Snapshot Levels (Schedule):** Configure how often to take automatic snapshots (optional).
    - **User Home Directories:** Decide whether to include user home directories. By default, hidden files are included. You can exclude all user files or include all. For system restore purposes, often only system files are needed. Personal data should be backed up separately with a different tool (e.g., `rsync`, Pika Backup, BackInTime).
3.  **Create Your First Snapshot:** Click "Create". Add a comment if desired.

**Timeshift CLI Commands:**

```bash
sudo timeshift --list                # List available snapshots
# sudo timeshift --list --snapshot-device /dev/sdaX # List snapshots on a specific device

sudo timeshift --create --comments "Clean install baseline" --tags D # Create daily snapshot
# sudo timeshift --restore # Interactively restore from a snapshot
# sudo timeshift --restore --snapshot 'YYYY-MM-DD_HH-MM-SS' --target /dev/sdXY # Restore specific snapshot to target
# sudo timeshift --delete --snapshot 'YYYY-MM-DD_HH-MM-SS' # Delete specific snapshot
# sudo timeshift --delete-all # Delete ALL snapshots
```

If Timeshift GUI doesn't open in some window managers, try: `sudo -E timeshift-gtk`

---

This revised guide(originally git:swapnanil1/arch) should be much easier to follow and provide a solid foundation for your Arch Linux setup! Remember to adapt it to your specific needs and hardware.
