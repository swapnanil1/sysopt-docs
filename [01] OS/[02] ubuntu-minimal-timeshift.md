This is the finalized, comprehensive guide for **Ubuntu 25.04 (Plucky Puffin)** + BTRFS + NoSnap.

### Step 1: Prepare the Live Environment
Boot from an Ubuntu 25.04 Live USB, open a terminal, and switch to root.

```bash
sudo -i
apt update && apt install -y debootstrap arch-install-scripts
```

---

### Step 2: Disk Partitioning (UEFI/GPT)
*Replace `/dev/nvme0n1` with your actual drive.*

```bash
# 1. Create GPT label and partitions
parted -s /dev/nvme0n1 -- mklabel gpt \
  mkpart EFI fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart "Ubuntu" btrfs 513MiB 100%

# 2. Format partitions
mkfs.fat -F 32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L Ubuntu -f /dev/nvme0n1p2
```

---

### Step 3: BTRFS Subvolumes & Mounting
We use ZSTD compression and `noatime` for SSD optimization.

```bash
# 1. Create subvolumes
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# 2. Mount with ZSTD compression
mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi /mnt/home
mount /dev/nvme0n1p1 /mnt/boot/efi
mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
```

---

### Step 4: Install Base System
```bash
debootstrap --arch=amd64 plucky /mnt
```

---

### Step 5: Fstab Generation & Critical Cleanup
This addresses the issue where `genfstab` adds `subvolid`, which can cause boot failure if subvolumes are moved or recreated.

1. **Generate the initial table:**
   ```bash
   genfstab -U /mnt >> /mnt/etc/fstab
   ```

2. **Manual Cleanup:**
   Open the file: `nano /mnt/etc/fstab`
   *   Locate the lines for `/` and `/home`.
   *   **Remove** the `subvolid=XXX` parts from the options.
   *   **Verify** the options match: `noatime,compress=zstd,subvol=@` (and `@home`).
   *   Ensure the EFI partition has `umask=0077`.

   **Your fstab should look exactly like this (with your UUIDs):**
   ```text
   UUID=XXXX-XXXX      /boot/efi  vfat   umask=0077      0  1
   UUID=YOUR-BTRFS-ID  /          btrfs  noatime,compress=zstd,subvol=@  0  0
   UUID=YOUR-BTRFS-ID  /home      btrfs  noatime,compress=zstd,subvol=@home  0  0
   ```

---

### Step 6: Chroot and Snap Blocking
```bash
# 1. Enter the system
arch-chroot /mnt

# 2. Hard-Block Snaps
cat <<EOF > /etc/apt/preferences.d/nosnap
Package: snapd
Pin: release a=*
Pin-Priority: -1
EOF

# 3. Configure Repositories
cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ plucky main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ plucky-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ plucky-security main restricted universe multiverse
EOF

apt update
```

---

### Step 7: Install Snap-Free Ubuntu Desktop
This command installs the full Ubuntu experience (Dock, Tiling, Yaru) via native `.deb` packages.

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
  unzip zip curl wget sudo alsa-utils
```

---

### Step 8: Install Brave Browser (Native .deb)
```bash
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt update && apt install -y brave-browser
```

---

### Step 9: Critical Boot Configuration
Essential for BTRFS root mounting and GRUB functionality.

```bash
# 1. User & Hostname
echo "ubuntu-btrfs" > /etc/hostname
useradd -m -G sudo -s /bin/bash yourusername
passwd yourusername
passwd # Set root password

# 2. Initramfs BTRFS support
echo "btrfs" >> /etc/initramfs-tools/modules
update-initramfs -u

# 3. GRUB configuration for Subvolumes
UUID=$(blkid -s UUID -o value $(lsblk -no NAME,LABEL | grep "Ubuntu" | awk '{print "/dev/"$1}'))
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"root=UUID=$UUID rootflags=subvol=@\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub

# 4. Networking
systemctl enable NetworkManager
```

---

### Step 10: Finalize and Reboot
```bash
exit
umount -R /mnt
reboot
```

### Post-Install Verification
*   **Snap-free:** `snap list` should fail or show nothing.
*   **Fstab:** `cat /etc/fstab` should show only `subvol=@` with no `subvolid`.
*   **Compression:** `compize /` (if installed) or `mount | grep btrfs` will show `zstd` active.
*   **Ubuntu UI:** At the login screen, verify the "Ubuntu" session is selected for the dock/tiling.
