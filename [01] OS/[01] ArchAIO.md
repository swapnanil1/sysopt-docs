# Arch Linux Performance & Setup Guide

This guide provides a comprehensive walkthrough for configuring a fresh Arch Linux installation. It is structured to follow a logical progression, from initial system setup to advanced performance tuning for daily use and gaming.

**Note:**
*   Replace `<your_username>` with your actual username where applicable.
*   The guide uses `sudo vim <file>`, but you can use any terminal-based editor like `nano`.

---

### **Table of Contents**

1.  [First Steps: Core System Setup](#1-first-steps-core-system-setup)
2.  [Essential Packages & Services](#2-essential-packages--services)
3.  [Shell & AUR Helper Configuration](#3-shell--aur-helper-configuration)
4.  [Hardware & Drivers](#4-hardware--drivers)
5.  [Desktop Environment & Applications](#5-desktop-environment--applications)
6.  [Storage: Mounting Additional Drives](#6-storage-mounting-additional-drives)
7.  [System Optimization & Tuning](#7-system-optimization--tuning)
8.  [Linux Gaming Setup](#8-linux-gaming-setup)
9.  [System Backup with Timeshift](#9-system-backup-with-timeshift)
10. [Advanced & Specific Use Cases](#10-advanced--specific-use-cases)

---

## 1. First Steps: Core System Setup

These are the immediate priorities after a base Arch Linux installation.

### 1.1. Connect to the Internet

If you are using a wired connection, it should work automatically. For Wi-Fi, `NetworkManager` is the standard choice.

```bash
sudo pacman -S --needed networkmanager
sudo systemctl enable --now NetworkManager.service
```

To connect to a Wi-Fi network from the command line, you can use `nmtui` for a simple interface or `nmcli`:

```bash
# List available Wi-Fi networks
nmcli device wifi list
# Connect to a network
nmcli device wifi connect "Your_SSID" password "Your_Password"
```

### 1.2. Optimize Pacman Mirrors

Using faster, up-to-date mirrors will significantly speed up package downloads.

```bash
# Install reflector
sudo pacman -S --needed reflector

# Backup the original mirrorlist
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

# Generate a new mirrorlist with the fastest mirrors in your region
# Change 'India,Singapore' to your country and nearby ones.
sudo reflector --verbose --latest 10 --country 'India,Singapore' --sort rate --protocol https --save /etc/pacman.d/mirrorlist
```

After updating your mirrors, perform a full system upgrade to ensure everything is current.

```bash
sudo pacman -Syu
```

### 1.3. Automate Package Cache Cleanup

Prevent your package cache from consuming excessive disk space by automatically cleaning it after transactions.

First, install the necessary tool:
```bash
sudo pacman -S --needed pacman-contrib
```

Next, create a pacman hook to trigger the cleanup:

```bash
sudo mkdir -p /etc/pacman.d/hooks
sudo vim /etc/pacman.d/hooks/clean_package_cache.hook```

Paste the following content. This configuration keeps the two most recent versions of each package.

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

## 2. Essential Packages & Services

Install core utilities and enable foundational system services.

### 2.1. Core System Components

```bash
sudo pacman -S --needed dkms dbus ufw git wget cronie openssh htop smartmontools xdg-user-dirs
```

### 2.2. Common System Services

Enable services for task scheduling, firewall, time synchronization, and hardware events.

```bash
sudo systemctl enable cronie.service
sudo systemctl enable ufw.service
sudo systemctl enable systemd-timesyncd.service
sudo systemctl enable acpid.service
sudo systemctl enable avahi-daemon.service
```

For SSDs, enable the TRIM timer to maintain drive performance:
```bash
sudo systemctl enable fstrim.timer
```

### 2.3. Basic Firewall Configuration (UFW)

Set up a simple and effective firewall policy.

```bash
# Deny all incoming traffic and allow all outgoing traffic
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Enable the firewall
sudo ufw enable
```**Important**: If you need to access this machine via SSH, you must explicitly allow it:
```bash
sudo ufw allow ssh
```

### 2.4. Filesystem and Archive Utilities

Install tools for managing various filesystems and archive formats.

```bash
# Filesystem support
sudo pacman -S --needed nfs-utils cifs-utils ntfs-3g exfat-utils gvfs udisks2

# Archive format support
sudo pacman -S --needed p7zip unrar unzip xz rsync zip
```

### 2.5. Multimedia Codecs

Install a comprehensive set of codecs for broad multimedia playback support.

```bash
sudo pacman -S --needed gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gstreamer-vaapi x265 x264 lame
```

### 3.0. Shell & AUR Helper Configuration

Customize your shell, gain access to the Arch User Repository (AUR), and optionally switch to a more modern shell like Fish.

#### 3.1. Install an AUR Helper (`paru`)

The AUR contains thousands of community-maintained packages. An AUR helper like `paru` automates the process of building and installing them.

```bash
# Ensure required build tools are installed
sudo pacman -S --needed base-devel git

# Clone, build, and install paru
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin
makepkg -si
cd .. && rm -rf paru-bin
```

#### 3.2. Customize Your Shell with Aliases

You can enhance your shell with aliases for common commands. This saves time and reduces typos.

*   **For Bash**, edit `~/.bashrc`.
*   **For Zsh**, edit `~/.zshrc`.

```bash
# Replace ls with a modern alternative like eza (must be installed)
alias ls='eza -al --color=always --group-directories-first'
alias la='eza -a --color=always --group-directories-first'

# Pacman and Paru shortcuts
alias update='sudo pacman -Syu && paru -Sua'
alias pi='sudo pacman -S'
alias prs='sudo pacman -Rns'

# Use Neovim instead of Vim
alias vim='nvim'
```After editing, reload your shell's configuration (`source ~/.bashrc`) or open a new terminal.

#### 3.3. Optional: Switch to Fish Shell

Fish (Friendly Interactive Shell) offers advanced features out-of-the-box like autosuggestions, syntax highlighting, and simpler scripting.

```bash
# Install Fish and a recommended Nerd Font for better terminal icons
sudo pacman -S --needed fish ttf-jetbrains-mono-nerd

# Set Fish as the default shell for your user
chsh -s /usr/bin/fish <your_username>
```
You must **log out and log back in** for the change to take effect. Note that Fish configuration is done in `~/.config/fish/config.fish` and its alias syntax is slightly different (e.g., `alias update 'sudo pacman -Syu && paru -Sua'`).

## 4. Hardware & Drivers

Configure audio, graphics, and other hardware.

### 4.1. Sound System (PipeWire)

PipeWire is the modern standard for audio on Linux.

```bash
sudo pacman -S --needed alsa-utils pipewire pipewire-pulse pipewire-jack wireplumber realtime-privileges
```

For improved audio performance and lower latency, add your user to the `realtime` group.
```bash
sudo gpasswd -a <your_username> realtime
```
You will need to log out and log back in for this change to take effect.

For graphical audio control, install `pavucontrol` (GTK) or `pavucontrol-qt` (Qt).
```bash
# For GTK-based desktops (GNOME, XFCE)
sudo pacman -S --needed pavucontrol

# For Qt-based desktops (KDE Plasma)
sudo pacman -S --needed pavucontrol-qt
```

### 4.2. Graphics Drivers

Install the appropriate drivers for your graphics card.

**For AMD (Mesa):**
```bash
sudo pacman -S --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
```

**For NVIDIA:**
```bash
# For modern GPUs
sudo pacman -S --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings

# For CUDA/OpenCL support
sudo pacman -S --needed opencl-nvidia cuda
```
**Note**: The `nvidia-dkms` package is generally preferred as it rebuilds automatically for new kernels. Consult the Arch Wiki for drivers for older cards.

### 4.3. Bluetooth Support

```bash
sudo pacman -S --needed bluez bluez-utils
sudo systemctl enable --now bluetooth.service
```

## 5. Desktop Environment & Applications

Set up your graphical interface and install essential software.

### 5.1. Fonts

A good set of fonts is essential for proper rendering in applications and on the web.

```bash
sudo pacman -S --needed ttf-dejavu ttf-liberation noto-fonts ttf-jetbrains-mono-nerd adobe-source-code-pro-fonts
```
For emoji and East Asian language support, also install `noto-fonts-emoji` and `noto-fonts-cjk`.

#### 5.2. Desktop Environment

Choose **one** desktop environment. After installing the base system, you can add optional applications and themes to complete the experience.

##### **KDE Plasma 6 (Minimal & Modular)**
*(Base installation instructions are the same)*

*   **Optional Post-Installation Apps & Themes:**
    To create a more full-featured KDE experience, you can install the common application suite and additional themes.
    ```bash
    # KDE application suite
    sudo pacman -S --needed okular gwenview kate kdenlive kdeconnect

    # Extra themes and customization tools
    sudo pacman -S --needed materia-kde materia-gtk-theme kvantum
    ```

##### **GNOME**
*(Base installation instructions are the same)*

*   **Optional Post-Installation Apps & Themes:**
    Install essential GNOME utilities and popular themes to customize the look and feel.
    ```bash
    # Core GNOME utilities and customization tools
    sudo pacman -S --needed gnome-tweaks gnome-shell-extensions gnome-system-monitor

    # Popular themes for a different look
    sudo pacman -S --needed arc-gtk-theme papirus-icon-theme
    ```

##### **Cinnamon**
*(Base installation instructions are the same)*

*   **Optional Post-Installation Apps & Themes:**
    Install the standard suite of applications from the Linux Mint ecosystem and popular themes.
    ```bash
    # Core Mint applications and Nemo file manager extensions
    paru -S --needed xed pix webapp-manager nemo-fileroller nemo-preview
    
    # Standard Mint themes and icons
    paru -S --needed mint-themes mint-y-icons
    ```
---

#### 5.3. Essential Applications

Install a powerful terminal, text editor, web browser, and other key applications.

##### 5.3.1. Terminal and CLI Tools

Alacritty is a fast, GPU-accelerated terminal emulator. `eza`, `fd`, and `ripgrep` are modern, faster replacements for `ls`, `find`, and `grep`.

```bash
sudo pacman -S --needed alacritty eza fd ripgrep
```
*   **Optional: Alacritty Themes**
    You can easily add themes to Alacritty for further customization.
    ```bash
    mkdir -p ~/.config/alacritty/themes
    git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes
    ```
    To apply a theme, you will need to edit `~/.config/alacritty/alacritty.yml` and add an `import` line pointing to your chosen theme file.

##### 5.3.2. Text Editor: Neovim with LazyVim

Install Neovim and its key dependencies, then set up LazyVim for a powerful, pre-configured IDE-like experience.

1.  **Install Neovim and Dependencies:**
    ```bash
    sudo pacman -S --needed neovim python-pynvim nodejs npm
    ```

2.  **Back Up Existing Neovim Configuration (if any):**
    ```bash
    mv ~/.config/nvim{,.bak}
    mv ~/.local/share/nvim{,.bak}
    ```

3.  **Clone the LazyVim Starter:**
    ```bash
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    ```

4.  **Start Neovim:**
    Launch `nvim`. LazyVim will automatically bootstrap itself and install all the configured plugins.

##### 5.3.3. IDE: Code - OSS

For a full-featured Visual Studio Code experience using the open-source build, install these packages to enable settings sync and access to the official Microsoft marketplace.

```bash
paru -S --needed code code-features code-marketplace
```

##### 5.3.4. Web Browsers & Common Applications

Install your choice of web browsers and other daily-use applications.

```bash
# Web Browsers
paru -S --needed firefox brave-bin

# Common Applications
paru -S --needed telegram-desktop keepassxc mpv qbittorrent bleachbit onlyoffice-bin
```


## 6. Storage: Mounting Additional Drives

This section covers formatting a new drive and setting it to auto-mount at boot.

**Warning:** The following steps will erase all data on the target partition. Double-check your device names (`/dev/sdXn`).

1.  **Identify Your Drive:**
    Use `lsblk -f` to list all block devices and their partitions. Identify the target partition (e.g., `/dev/sdb1`).

2.  **Format the Partition:**
    This example formats the drive to `ext4`.
    ```bash
    sudo mkfs.ext4 /dev/sdb1
    ```

3.  **Create a Mount Point:**
    This is the directory where the drive's contents will be accessible.
    ```bash
    sudo mkdir /mnt/MyData
    ```

4.  **Change Ownership:**
    Mount the drive temporarily to change its permissions, giving your user read and write access.
    ```bash
    sudo mount /dev/sdb1 /mnt/MyData
    sudo chown -R <your_username>:<your_username> /mnt/MyData
    sudo umount /mnt/MyData
    ```

### **5. Configure Auto-Mounting (`fstab`)**

To make a drive mount automatically on boot, you need to add it to `/etc/fstab`. This file acts as a map for your system's storage devices.

**Warning:** An incorrect `fstab` entry can prevent your system from booting. Always double-check your syntax and back up the file before saving changes.

1.  **Get the Partition's `UUID`:**
    First, find the persistent `UUID` of your partition. Using the `UUID` is safer than using device names like `/dev/sdb1`, which can change.
    ```bash
    sudo blkid /dev/sdb1
    ```
    Copy the `UUID` value from the output.

2.  **Backup and Edit `fstab`:**
    ```bash
    sudo cp /etc/fstab /etc/fstab.bak
    sudo vim /etc/fstab
    ```

3.  **Add the Mount Entry:**
    Append a new line to the end of the file using one of the presets below. Remember to replace `<your_uuid>` with the actual UUID you copied and adjust the mount point (e.g., `/mnt/MyData`).

    ---

    #### **Preset 1: `ext4` Filesystem**

    ##### **A) Balanced (Recommended for most users)**
    This preset offers excellent performance while retaining important data safety features. It is ideal for drives storing important personal data or for a daily-driver system.

    ```fstab
    # <file system>    <mount point>    <type>  <options>                                         <dump> <pass>
    UUID=<your_uuid>   /mnt/MyData      ext4    defaults,noatime,rw,user,auto                     0      2
    ```

    ##### **B) Maximum Performance (Ideal for scratch disks, gaming libraries)**
    This configuration prioritizes raw speed by disabling journaling features that ensure data consistency. Use this for data that is easily replaceable, like a Steam library or temporary build files. **Do not use this for your root filesystem or for storing critical data.**

    ```fstab
    # <file system>    <mount point>    <type>  <options>                                                               <dump> <pass>
    UUID=<your_uuid>   /mnt/MyGames     ext4    rw,noatime,user,auto,data=writeback,barrier=0,nobh,errors=remount-ro    0      0
    ```
    ---

    #### **Preset 2: `BTRFS` Filesystem (for SSDs/NVMe)**

    ##### **A) Balanced (Recommended for data integrity and speed)**
    This is the modern, recommended approach for BTRFS. It leverages key features like compression and efficient SSD handling without compromising on BTRFS's core data protection capabilities.

    ```fstab
    # <file system>    <mount point>       <type>  <options>                                                                 <dump> <pass>
    UUID=<your_uuid>   /mnt/MyBtrfsDrive   btrfs   rw,noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,autodefrag   0      0
    ```

    ##### **B) Maximum Performance (For VMs, databases, non-critical files)**
    This preset disables Copy-on-Write (`cow`) and data checksumming, which significantly boosts performance for specific workloads like virtual machine images or database files. This comes at the cost of BTRFS's self-healing and data integrity features. **Use this only on specific subvolumes intended for this purpose.**

    ```fstab
    # <file system>    <mount point>      <type>  <options>                                                                   <dump> <pass>
    UUID=<your_uuid>   /mnt/BtrfsVMs      btrfs   rw,noatime,ssd,discard=async,nodatasum,nodatacow,space_cache=v2              0      0
    ```
    ---

    **Explanation of Key Options:**

    *   **`defaults`**: A standard set of options (`rw`, `suid`, `dev`, `exec`, `auto`, `nouser`, `async`).
    *   **`noatime`**: A crucial performance tweak that disables writing file access timestamps.
    *   **`discard=async`**: Enables continuous TRIM for SSDs, which helps maintain performance over time.
    *   **`compress=zstd:3`**: (BTRFS) Enables transparent compression with the `zstd` algorithm at level 3, offering a great balance between speed and compression ratio.
    *   **`space_cache=v2`**: (BTRFS) A more robust and performant way for BTRFS to manage its free space cache.
    *   **`autodefrag`**: (BTRFS) Helps reduce fragmentation for desktop workloads, though it can be disabled for servers with large files.
    *   **`data=writeback`**: (ext4 Performance) Only metadata is journaled, not the data itself. Faster, but can lead to data corruption in a crash.
    *   **`barrier=0`**: (ext4 Performance) Disables write barriers, offering a speed boost at the risk of filesystem corruption during a power failure.
    *   **`nodatacow`**: (BTRFS Performance) Disables Copy-on-Write. This also disables checksumming and compression for any files affected. **Changes are not retroactive.**
    *   **`nodatasum`**: (BTRFS Performance) Disables the creation of data checksums, removing a layer of integrity checking.

6.  **Test and Mount:**
    To test your `fstab` entry without rebooting, run:
    ```bash
    sudo mount -a
    ```    If no errors appear, your drive is now mounted. If you see errors, restore your backup (`sudo mv /etc/fstab.bak /etc/fstab`) and troubleshoot the entry.

## 7. System Optimization & Tuning

Fine-tune your system for better performance and responsiveness.

### 7.1. Enhanced DNS with `systemd-resolved`

Use DNS-over-TLS for improved privacy and speed.

1.  **Configure `resolved.conf`:**
    ```bash
    sudo vim /etc/systemd/resolved.conf
    ```
    Uncomment and modify the `[Resolve]` section. Below is an example using Quad9's DNS servers.

    ```ini
    [Resolve]
    DNS=9.9.9.9
    FallbackDNS=1.1.1.1
    DNSOverTLS=yes
    DNSSEC=no
    Cache=yes
    ```
2.  **Enable the Service:**
    ```bash
    sudo systemctl enable --now systemd-resolved.service
    ```
3.  **Link `resolv.conf`:**
    Ensure the system uses `systemd-resolved` for DNS lookups by creating a symbolic link.
    ```bash
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    ```
4.  **Restart NetworkManager:**
    ```bash
    sudo systemctl restart NetworkManager
    ```

### 7.2. Microphone Noise Suppression

This filter uses RNNoise to remove background noise from your microphone input, which is excellent for calls and recording.

1.  **Install the Plugin:**
    ```bash
    sudo pacman -S --needed noise-suppression-for-voice
    ```
2.  **Create a PipeWire Filter Configuration:**
    ```bash
    mkdir -p ~/.config/pipewire/pipewire.conf.d/
    vim ~/.config/pipewire/pipewire.conf.d/99-input-denoising.conf
    ```
3.  **Paste the following:**
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
                            control = { "VAD Threshold (%)" = 50.0 }
                        }
                    ]
                }
                capture.props = {
                    node.name = "capture.rnnoise_source"
                    node.passive = true
                    audio.rate = 48000
                }
                playback.props = {
                    node.name = "rnnoise_source"
                    media.class = Audio/Source
                    audio.rate = 48000
                }
            }
        }
    ]
    ```
4.  **Restart PipeWire Services:**
    ```bash
    systemctl --user restart pipewire pipewire-pulse wireplumber
    ```
    After restarting, a new input device named "Noise Canceling Source" will be available in your audio settings. Select it in your applications for a clear microphone signal.

## 8. Linux Gaming Setup

Optimize your system for a great gaming experience.

### 8.1. Steam & Lutris

Install Steam for native Linux games and Proton, and Lutris for managing games from other sources.

```bash
# Enable the [multilib] repository in /etc/pacman.conf first!
sudo pacman -S --needed steam lutris
```

### 8.2. Wine and Dependencies

Install `wine-staging` and the essential libraries needed to run Windows games. This tiered approach starts with the absolute minimum and lets you add more if needed.

**Tier 1: Core Wine Installation (Essential)**
```bash
sudo pacman -S --needed wine-staging wine-mono wine-gecko winetricks
```

**Tier 2: Minimal Runtime Dependencies (Highly Recommended)**
These cover most basic requirements for games to launch.
```bash
sudo pacman -S --needed lib32-giflib lib32-gnutls lib32-v4l-utils lib32-libpulse lib32-alsa-plugins lib32-sqlite lib32-libxcomposite lib32-libva lib32-vulkan-icd-loader
```

**Tier 3: Common Optional Dependencies (Install if Needed)**
Install these only if a specific game or application fails to run.
```bash
# sudo pacman -S --needed lib32-gst-plugins-base-libs lib32-ocl-icd lib32-gtk3 lib32-sdl2
```

### 8.3. Gaming Tools & Utilities

*   **MangoHud:** An overlay to display FPS, CPU/GPU usage, and more.
*   **Gamescope:** A micro-compositor that provides better control over game resolution, refresh rate, and scaling.
*   **ProtonUp-Qt:** A graphical tool to easily install and manage community builds of Proton (Proton-GE) and Wine (Wine-GE).

```bash
sudo pacman -S --needed mangohud lib32-mangohud gamescope
paru -S --needed protonup-qt
```
To use MangoHud in Steam, add `mangohud %command%` to a game's launch options.

### 8.4. Performance Tweaks

**Increase `vm.max_map_count`:**
Some games, like CS2 and Elden Ring, require a higher memory map limit.
```bash
sudo vim /etc/sysctl.d/80-gamecompatibility.conf
```
Add the following line:
```
vm.max_map_count = 262144
```
Apply the change immediately with `sudo sysctl --system`.

**Kernel Parameters (Advanced):**
For maximum performance, you can add parameters to your bootloader's kernel command line.
**Warning:** `mitigations=off` disables certain CPU security mitigations. Understand the security risks before using it.

Example parameters for an AMD GPU:
`mitigations=off amdgpu.ppfeaturemask=0xffffffff`

Consult the Arch Wiki for instructions on how to add these to GRUB or `systemd-boot`.

## 9. System Backup with Timeshift

Before you start heavy customization, create a system snapshot. Timeshift is an excellent tool for this.

1.  **Install Timeshift:**
    ```bash
    sudo pacman -S --needed timeshift
    ```
2.  **Launch and Configure:**
    Run `sudo timeshift-gtk` from the terminal or find it in your application menu.
    *   **Snapshot Type:** **Rsync** is recommended and works on any filesystem. Choose Btrfs only if your root partition (`/`) is Btrfs.
    *   **Location:** Select a separate drive or partition for your snapshots. **Do not store system backups on the same drive as the OS.**
    *   **Schedule:** Configure automated snapshots if desired.
    *   **User Home Directories:** For system restoration, it's often best to **exclude** user home directories. Back up your personal data separately.
3.  **Create Your First Snapshot:**
    Click the "Create" button to make your first manual backup. This will be your clean baseline to restore to if anything goes wrong.

## 10. Advanced & Specific Use Cases

This section covers tools and configurations for more specific needs.

### 10.1. Overclocking AMD GPUs (`corectrl`)

`corectrl` provides a graphical interface to control GPU clock speeds, fan curves, and power settings.

**Warning:** Overclocking can cause system instability or damage hardware. Proceed with caution.

1.  **Install `corectrl`:**
    ```bash
    sudo pacman -S --needed corectrl
    ```
2.  **Add Kernel Parameter:**
    You must add `amdgpu.ppfeaturemask=0xffffffff` to your bootloader's kernel parameters and reboot for `corectrl` to have full access.
3.  **Configure Permissions:**
    To allow `corectrl` to apply settings without asking for a password every time, create a Polkit rule.
    ```bash
    sudo vim /etc/polkit-1/rules.d/90-corectrl.rules
    ```
    Paste the following, replacing `your_username`.
    ```javascript
    polkit.addRule(function(action, subject) {
        if (action.id.startsWith("org.corectrl") && subject.user == "your_username") {
            return polkit.Result.YES;
        }
    });
    ```
    After setting this up and rebooting, you can create performance profiles for your applications.

### 10.2. Android Debug Bridge (ADB)

For managing Android devices from your PC.

1.  **Install Tools:**
    ```bash
    sudo pacman -S --needed android-tools android-udev
    ```
2.  **Add User to `adbusers` Group:**
    ```bash
    sudo usermod -aG adbusers <your_username>
    ```
    You must log out and log back in for the group change to apply. After that, you can run `adb devices` to see your connected phone (once authorized on the device).
