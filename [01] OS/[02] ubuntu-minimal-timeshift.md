# Ubuntu 25.10 (Questing Quokka) Minimal Install Guide

This guide provides a manual, surgical installation of Ubuntu 25.10 from a live environment. It is designed for maximum performance using a BTRFS subvolume layout and a total hard-block on Snap packages.

## Step 1: Prepare the Live Environment
Boot from an Ubuntu 25.10 Live USB, open a terminal, and switch to the root user.

```bash
sudo -i
apt update && apt install -y debootstrap arch-install-scripts
```

---

## Step 2: Disk Partitioning (UEFI/GPT)
*Replace `/dev/nvme0n1` with your actual target drive.*

```bash
# 1. Create GPT label and partitions (512MB EFI, rest BTRFS)
parted -s /dev/nvme0n1 -- mklabel gpt \
  mkpart EFI fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart "Ubuntu" btrfs 513MiB 100%

# 2. Format partitions
mkfs.fat -F 32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L Ubuntu -f /dev/nvme0n1p2
```

---

## Step 3: BTRFS Subvolumes & Mounting
We use separate subvolumes for the system (`@`) and user data (`@home`) to facilitate easy snapshots and rollbacks with ZSTD compression.

```bash
# 1. Create subvolumes
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# 2. Mount with ZSTD compression and SSD optimizations
mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi /mnt/home
mount /dev/nvme0n1p1 /mnt/boot/efi
mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
```

---

## Step 4: Install Base System
We use the codename **`questing`** for Ubuntu 25.10.

```bash
debootstrap --arch=amd64 questing /mnt
```

---

## Step 5: Fstab Generation & Critical Cleanup
`genfstab` is helpful, but we must manually remove `subvolid` references to ensure the fstab remains reliable if subvolumes are moved or snapshotted.

1. **Generate the table:**
   ```bash
   genfstab -U /mnt >> /mnt/etc/fstab
   ```

2. **Manual Cleanup:**
   Open the file: `nano /mnt/etc/fstab`
   *   Locate the lines for `/` and `/home`.
   *   **Remove** any `subvolid=XXX` parameters from the options list.
   *   **Verify** the options match: `noatime,compress=zstd,subvol=@` (and `@home`).
   *   Ensure the EFI partition has `umask=0077`.

   **Example of a clean fstab:**
   ```text
   UUID=XXXX-XXXX      /boot/efi  vfat   umask=0077      0  1
   UUID=YOUR-BTRFS-ID  /          btrfs  noatime,compress=zstd,subvol=@  0  0
   UUID=YOUR-BTRFS-ID  /home      btrfs  noatime,compress=zstd,subvol=@home  0  0
   ```

---

## Step 6: Chroot and Snap Blocking
```bash
# 1. Enter the new system
arch-chroot /mnt

# 2. Hard-Block Snapd
cat <<EOF > /etc/apt/preferences.d/nosnap
Package: snapd
Pin: release a=*
Pin-Priority: -1
EOF

# 3. Configure Repositories
cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ questing main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ questing-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ questing-security main restricted universe multiverse
EOF

apt update
```

---

## Step 7: Install Snap-Free Ubuntu Desktop
This command installs the full Ubuntu GNOME 49 experience using native `.deb` packages.

```bash
apt install -y --no-install-recommends \
  linux-image-generic linux-headers-generic linux-firmware \
  grub-efi-amd64 btrfs-progs \
  ubuntu-session ubuntu-settings gdm3 \
  gnome-shell gnome-control-center nautilus gnome-terminal \
  gnome-shell-extension-ubuntu-dock \
  gnome-shell-extension-ubuntu-tiling-assistant \
  gnome-shell-extension-appindicator \
  gnome-shell-extension-desktop-icons-ng \
  yaru-theme-gtk yaru-theme-icon yaru-theme-sound yaru-theme-gnome-shell \
  fonts-ubuntu ubuntu-wallpapers \
  network-manager pipewire-pulse wireplumber bluez \
  gnome-calculator gnome-text-editor gnome-characters \
  gnome-disk-utility evince eog baobab \
  xdg-user-dirs-gtk xdg-utils software-properties-gtk \
  unzip zip curl wget sudo alsa-utils wpa-supplicant
```

---

## Step 8: Install Brave Browser (Native .deb)
```bash
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt update && apt install -y brave-browser
```

---

## Step 9: Critical Boot Configuration
Essential steps to ensure the system handles the BTRFS root subvolume and the new Rust-based core utilities correctly.

```bash
# 1. Set Hostname and User
echo "darkgrid" > /etc/hostname
useradd -m -G sudo,input,audio,video -s /bin/bash swapnanil
passwd swapnanil

# 2. Add BTRFS support to the Initramfs
echo "btrfs" >> /etc/initramfs-tools/modules
echo "nvme" >> /etc/initramfs-tools/modules
update-initramfs -c -k -all

# 3. Configure GRUB for Subvolume Booting
UUID=$(blkid -s UUID -o value $(lsblk -no NAME,LABEL | grep "Ubuntu" | awk '{print "/dev/"$1}'))
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"root=UUID=$UUID rootflags=subvol=@\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub

# 4. Enable Networking
systemctl enable NetworkManager
```

---

## Step 10: Finalize and Reboot
```bash
exit
umount -R /mnt
reboot
```

### Post-Install Verification
*   **No Snaps:** Run `snap list`. It should return a "command not found" error.
*   **BTRFS Mounts:** Run `mount | grep btrfs`. You should see `subvol=/@` and `compress=zstd`.
*   **Rust Coreutils:** Ubuntu 25.10 uses `uutils`. You can verify this by checking `ls --version`.
*   **Visuals:** At the login screen, ensure the **Ubuntu** session is selected (via the gear icon) to enable the Dock and Yaru themes.

this is final i am usingf now check again all the commands are correct or not
