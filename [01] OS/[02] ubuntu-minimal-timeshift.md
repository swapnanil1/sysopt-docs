# Ubuntu 25.10 (Questing Quokka) - Minimalist "Nuclear" Guide
### BTRFS + NoSnap + GNOME + Zero Telemetry

## Step 1: Prepare the Live Environment
```bash
sudo -i
apt update && apt install -y debootstrap arch-install-scripts
```

## Step 2: Disk Partitioning (UEFI/GPT)
```bash
# Replace /dev/nvme0n1 with your drive
parted -s /dev/nvme0n1 -- mklabel gpt \
  mkpart EFI fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart "Ubuntu" btrfs 513MiB 100%

mkfs.fat -F 32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L Ubuntu -f /dev/nvme0n1p2
```

## Step 3: BTRFS Subvolumes & Mounting
```bash
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# Mount with compression
mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi /mnt/home
mount /dev/nvme0n1p1 /mnt/boot/efi
mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
```

## Step 4: Install Base System
```bash
debootstrap --arch=amd64 questing /mnt
```

## Step 5: Fstab Cleanup (Subvolid Removal)
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```
*Action:* `nano /mnt/etc/fstab`. **Remove** all `subvolid=...` entries. Ensure they use `subvol=@` and `subvol=@home`. Ensure EFI has `umask=0077`.

## Step 6: Chroot and Snap Blocking
```bash
arch-chroot /mnt

# Block Snapd Forever
cat <<EOF > /etc/apt/preferences.d/nosnap
Package: snapd
Pin: release a=*
Pin-Priority: -1
EOF

# Configure Repositories
cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ questing main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ questing-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ questing-security main restricted universe multiverse
EOF

apt update
```

## Step 7: Install Snap-Free Modern Desktop

```bash
apt install -y --no-install-recommends \
  linux-image-generic linux-headers-generic linux-firmware firmware-sof-signed \
  grub-efi-amd64 btrfs-progs \
  ubuntu-session ubuntu-settings gdm3 \
  gnome-shell gnome-control-center nautilus gnome-console \
  gnome-shell-extension-ubuntu-dock \
  gnome-shell-extension-ubuntu-tiling-assistant \
  gnome-shell-extension-appindicator \
  gnome-shell-extension-desktop-icons-ng \
  yaru-theme-gtk yaru-theme-icon yaru-theme-sound yaru-theme-gnome-shell \
  fonts-ubuntu ubuntu-wallpapers \
  network-manager wpasupplicant bluez \
  pipewire-pulse wireplumber \
  gnome-calculator gnome-text-editor gnome-characters loupe \
  gnome-disk-utility evince baobab \
  xdg-user-dirs-gtk xdg-utils software-properties-gtk \
  unzip zip curl wget sudo alsa-utils
```

## Step 8: Install Brave Browser
```bash
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt update && apt install -y brave-browser
```

## Step 9: Localization & User Setup
**Do not skip this, or your hardware clock and keyboard will be wrong.**
```bash
# Timezone (Change to your region)
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

# Locales
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Keyboard
echo "KEYMAP=us" > /etc/vconsole.conf

# User
echo "darkgrid" > /etc/hostname
useradd -m -G sudo,input,audio,video -s /bin/bash swapnanil
passwd swapnanil
```

## Step 10: The "Nuclear" Boot Fix
This is where the Kernel Panic is solved. We force a fresh creation of the Initramfs.

```bash
# 1. Force modules
echo "btrfs" >> /etc/initramfs-tools/modules
echo "nvme" >> /etc/initramfs-tools/modules

# 2. Nuclear Initrd Rebuild (Create from scratch -c instead of update -u)
# Remove any broken existing ones first
rm -f /boot/initrd.img*
update-initramfs -c -k all

# 3. Configure GRUB
UUID=$(blkid -s UUID -o value -L Ubuntu)
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"root=UUID=$UUID rootflags=subvol=@ rw\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub

# 4. Final Services
systemctl enable NetworkManager
```

## Step 11: Finalize
```bash
exit
umount -R /mnt
reboot
```

---

### Critical Quirks & Troubleshooting

**Quirk 1: The Wi-Fi / NetworkManager Failure**
If you don't install `wpasupplicant` in a minimal debootstrap, NetworkManager will start but cannot scan for Wi-Fi networks. This guide includes it in Step 7.

**Quirk 2: The Missing BTRFS Initrd Module (Panic Fix)**
If `lsinitramfs /boot/initrd.img-... | grep btrfs` is empty, the kernel will panic. The fix is to use `update-initramfs -c` (Create) instead of `-u` (Update). Updating a minimal config often ignores new modules added to `/etc/initramfs-tools/modules`.

**Quirk 3: Rust Sudo (sudo-rs)**
Ubuntu 25.10 uses a Rust-based sudo. If you get a "sudo not found" error, ensure you installed the `sudo` package. The debootstrap doesn't always include it in the `base` variant.

**Quirk 4: No Sound on Laptops**
Modern Intel/AMD laptops require `firmware-sof-signed`. Without it, you will see a dummy output in sound settings. This guide includes it in Step 7.
