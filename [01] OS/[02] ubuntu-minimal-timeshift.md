# Ubuntu Minimal Install Guide (debootstrap + BTRFS)

This guide walks you through a manual, minimal installation of Ubuntu using command-line tools from a live environment. This method provides maximum control over your system's configuration, particularly for creating a BTRFS filesystem with a modern subvolume layout on a UEFI system.

| | |
| :--- | :--- |
| **Target Distribution** | Ubuntu (Latest Development Branch - "Plucky Puffin") |
| **Installation Method** | `debootstrap` and `arch-install-scripts` |
| **Filesystem** | BTRFS with `@` and `@home` subvolumes |
| **Firmware** | UEFI |
### Prerequisites

*   **Ubuntu Desktop Live ISO:** Download the latest version and create a bootable USB drive.
*   **Internet Connection:** Required for downloading packages during the installation.
*   **Target Machine:** A computer with UEFI firmware.
*   **Basic Linux CLI Knowledge:** Familiarity with partitioning and command-line operations is assumed.

***

## Step 1: Boot and Prepare the Live Environment

First, we'll boot into the live session, connect to the internet, and install the tools necessary for our manual installation.

1.  Boot your computer from the Ubuntu Live USB and select **"Try Ubuntu"**.
2.  Connect to the internet (wired or wireless).
3.  Open a terminal (`Ctrl+Alt+T`).
4.  Switch to the `root` user to avoid typing `sudo` for every command:
    ```bash
    sudo -i
    ```
5.  Update the package list and install our essential tools:
    ```bash
    apt update
    apt install -y debootstrap arch-install-scripts
    ```

***

## Step 2: Disk Partitioning

In this step, we will prepare the target disk by creating a new partition table and defining our partitions.

> **WARNING:** The following commands will erase all data on the specified disk. Double-check that `/dev/nvme0n1` is your correct target drive.

### 2.1. Prepare the Disk

1.  **Identify your target disk** (e.g., `/dev/nvme0n1`, `/dev/sda`).
2.  **(Optional but Recommended) Zap old partition tables.** This ensures a clean slate.
    ```bash
    # Run gdisk on your target disk
    gdisk /dev/nvme0n1
    ```
    Inside `gdisk`, press `x` for the expert menu, then `z` to zap (erase) all partition data, and confirm with `y`.

### 2.2. Create New Partitions with `parted`

This single command creates a GPT label and two partitions: one for EFI and one for our BTRFS system.

```bash
parted -s /dev/nvme0n1 -- \
  mklabel gpt \
  mkpart EFI fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart "Ubuntu" btrfs 513MiB 100%
```

### 2.3. Verify the Layout

Check that the partitions were created correctly.

```bash
parted /dev/nvme0n1 print
```

***

## Step 3: Format Partitions and Create BTRFS Subvolumes

Now we format the newly created partitions and set up the BTRFS subvolume structure, which is key to this installation method.

### 3.1. Format the Partitions

1.  **Format the EFI partition** as FAT32.
    ```bash
    mkfs.fat -F 32 -n EFI /dev/nvme0n1p1
    ```

2.  **Format the main partition** as BTRFS. Using a label is good practice.
    ```bash
    mkfs.btrfs -L Ubuntu /dev/nvme0n1p2
    ```

### 3.2. Create BTRFS Subvolumes

We will create separate subvolumes for the root (`/`) and home (`/home`) directories. This isolates system files from user data, making snapshots and rollbacks much cleaner.

1.  **Mount the top-level BTRFS volume** to a temporary location.
    ```bash
    mount /dev/nvme0n1p2 /mnt
    ```

2.  **Create the subvolumes** for root (`@`) and home (`@home`).
    ```bash
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    ```

3.  **Unmount the temporary top-level volume.**
    ```bash
    umount /mnt
    ```

***

## Step 4: Mount Filesystems for Installation

With the subvolumes created, we now mount them to `/mnt` in the final configuration that our new system will use. The mount options are critical here.

1.  **Mount the root subvolume (`@`)** to `/mnt`.
    > We use `noatime` (performance), `compress=zstd` (efficient compression), `ssd` (optimizations for SSDs), and `space_cache=v2` (improved space cache).
    ```bash
    mount -o noatime,compress=zstd,ssd,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt
    ```

2.  **Create the mount points** for other partitions inside the new root.
    ```bash
    mkdir -p /mnt/boot/efi
    mkdir /mnt/home
    ```

3.  **Mount the EFI partition.**
    ```bash
    mount /dev/nvme0n1p1 /mnt/boot/efi
    ```

4.  **Mount the home subvolume (`@home`).**
    ```bash
    mount -o noatime,compress=zstd,ssd,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/home
    ```

5.  **Verify the mounts.** The output should show your subvolumes mounted at `/` and `/home` within the `/mnt` tree.
    ```bash
    findmnt -R /mnt
    ```

***

## Step 5: Install the Base System

We will use `debootstrap` to download and install a minimal, core Ubuntu system into our prepared `/mnt` directory.

```bash
# We use 'plucky' for the 25.04 development release.
# For stable, use 'mantic' (23.10) or 'jammy' (22.04 LTS).
debootstrap --arch=amd64 plucky /mnt
```

***

## Step 6: Chroot and Configure the New System

Now we "change root" (`chroot`) into our new system to configure it from the inside. This includes setting up fstab, installing a kernel, configuring the bootloader, and creating a user.

### 6.1. Generate fstab

Use `genfstab` from `arch-install-scripts` to create the file system table.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

### 6.2. Important: Verify and Edit fstab

`genfstab` is good, but for BTRFS it often adds `subvolid` options which can be brittle. We will clean up `/etc/fstab` to use the more reliable `subvol=` option.

1.  Open the file: `nano /mnt/etc/fstab`.
2.  Find the lines for your BTRFS mounts.
3.  **Remove any `subvolid=...` options.**
4.  Ensure the lines use `subvol=@` and `subvol=@home` and match the options we used to mount them.
5.  Get UUIDs with `blkid` if needed.

> Your fstab should look like this:
> ```fstab
> # <file system>                 <mount point>  <type>  <options>                                                <dump> <pass>
> UUID=YOUR_EFI_UUID              /boot/efi      vfat    umask=0077                                                 0      1
> UUID=YOUR_BTRFS_PARTITION_UUID  /              btrfs   rw,noatime,compress=zstd,ssd,space_cache=v2,subvol=@       0      0
> UUID=YOUR_BTRFS_PARTITION_UUID  /home          btrfs   rw,noatime,compress=zstd,ssd,space_cache=v2,subvol=@home   0      0
> ```

### 6.3. Chroot into the New System

`arch-chroot` conveniently handles mounting pseudo-filesystems like `/dev`, `/proc`, and `/sys`.

```bash
arch-chroot /mnt
```

> **You are now operating inside your new Ubuntu installation.**

### 6.4. Configure APT Sources and Update

The base system has a minimal sources list. We need to add the `universe`, `multiverse`, and `restricted` repositories to access a full range of software.

1.  First, install a text editor: `apt install -y nano`
2.  Open the sources file: `nano /etc/apt/sources.list`
3.  Add the additional components. The file should look similar to this:
    ```sources.list
    deb http://archive.ubuntu.com/ubuntu/ plucky main restricted universe multiverse
    deb http://archive.ubuntu.com/ubuntu/ plucky-updates main restricted universe multiverse
    deb http://archive.ubuntu.com/ubuntu/ plucky-backports main restricted universe multiverse
    deb http://security.ubuntu.com/ubuntu/ plucky-security main restricted universe multiverse
    ```
4.  Update the package list from within the chroot:
    ```bash
    apt update
    ```
### 6.4.a. Disable Ubuntu snaps and other annoying stuff they do with apt
```bash
curl -sS 'https://raw.githubusercontent.com/swapnanil1/sysopt-docs/refs/heads/main/%5B01%5D%20OS/%5B02A%5D%20ignored-packages' | tee /etc/apt/preferences.d/ignored-packages > /dev/null
```

### 6.5. Install Core System & Graphical Environment

This is the main software installation. We'll install a kernel, bootloader, networking, audio, a full KDE graphical environment, and common applications.

1.  **Pre-accept Microsoft fonts license** to prevent the installation from pausing:
    ```bash
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
    ```
2.  **Run the main installation command.** We use `--no-install-recommends` for a minimal setup.
    ```bash
    sudo dpkg --add-architecture i386
    apt install -y --no-install-recommends \
    # --- CORE SYSTEM & BOOT ---
    linux-image-generic \
    linux-headers-generic \
    linux-firmware \
    grub-efi-amd64 \
    btrfs-progs \
    \
    # --- KDE DESKTOP ENVIRONMENT ---
    kde-standard \
    sddm-theme-breeze \
    \
    # --- CORE APPLICATIONS & UTILITIES ---
    wpasupplicant \
    fish \
    alacritty \
    htop \
    timeshift \
    cronie \
    software-properties-gtk \
    \
    # --- BUILD TOOLS & SYSTEM LIBRARIES ---
    build-essential \
    git \
    curl \
    wget \
    unzip
    ```
### 6.6. Install a Web Browser (Optional)

Choose **one** of the following options.

#### Option 1: Brave Browser (Scripted Install)
```bash
curl -fsS https://dl.brave.com/install.sh | sh
```

#### Option 2: Firefox (Native `.deb` via Mozilla's Repo)
```bash
# Add Mozilla's APT repository and key
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null
echo -e 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' | tee /etc/apt/preferences.d/mozilla

# Install Firefox
apt update
apt install firefox
```

### 6.7. Critical Boot Configuration (Preventative Fixes)

These next steps are crucial to ensure the system can find and mount the BTRFS root subvolume during boot.

#### PREVENTATIVE FIX 1: Configure Initramfs
We must ensure the `btrfs` module (and `nvme` if applicable) is loaded early in the boot process.
```bash
echo "btrfs" >> /etc/initramfs-tools/modules
# Add the line below if you are installing on an NVMe drive
echo "nvme" >> /etc/initramfs-tools/modules
```

#### PREVENTATIVE FIX 2: Configure GRUB
We need to tell the GRUB bootloader where to find our root filesystem by specifying its UUID and root subvolume.
1.  Find the UUID of your BTRFS partition (e.g., `/dev/nvme0n1p2`):
    ```bash
    blkid | grep "nvme0n1p2"
    ```
2.  Edit the GRUB default configuration file: `nano /etc/default/grub`.
3.  Find the `GRUB_CMDLINE_LINUX` line and modify it to look like this, replacing the placeholder with your actual UUID.
    > ```grub
    > # Find this line:
    > GRUB_CMDLINE_LINUX=""
    >
    > # And change it to:
    > GRUB_CMDLINE_LINUX="root=UUID=YOUR_BTRFS_PARTITION_UUID rootflags=subvol=@"
    > ```

### 6.8. Final System Configuration

1.  **Set Timezone, Locale, and Keyboard Layout.**
    ```bash
    dpkg-reconfigure tzdata
    dpkg-reconfigure locales
    dpkg-reconfigure keyboard-configuration
    ```
2.  **Set the Hostname.**
    ```bash
    echo "my-ubuntu" > /etc/hostname
    echo "127.0.0.1 localhost my-ubuntu" >> /etc/hosts
    ```
3.  **Enable Essential Services.**
    ```bash
    systemctl enable NetworkManager
    ```
4.  **Create a User Account.**
    ```bash
    # Creates user, adds to important groups, sets home dir
    useradd -m -G sudo,audio,video,input -s /bin/bash yourusername
    
    # Set the password for your new user
    passwd yourusername
    ```
5.  **Set a Root Password (Recommended).**
    ```bash
    passwd
    ```

### 6.9. Apply Bootloader and Initramfs Changes

This is the final and most critical step inside the chroot. These commands write our configuration changes to the bootloader and initial RAM disk.

1.  **Install GRUB** to the EFI partition.
    ```bash
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
    ```
2.  **Generate the GRUB** configuration file based on our settings.
    ```bash
    update-grub
    ```
3.  **Update the initramfs** for all installed kernels to include our new modules.
    ```bash
    update-initramfs -u -k all
    ```

***

## Step 7: Finalize and Reboot

The installation and configuration are complete. It's time to exit the chroot, unmount the partitions, and reboot into your new system.

1.  **Exit the chroot** environment.
    ```bash
    exit
    ```
2.  **Unmount all partitions.** The `-R` (recursive) flag handles this safely.
    ```bash
    umount -R /mnt
    ```
3.  **Reboot the system.**
    ```bash
    reboot
    ```
    Remove the installation media when prompted. Your new minimal Ubuntu system should now boot from the hard drive.

***

## Post-Install Verification & Troubleshooting

If the system doesn't boot correctly, don't panic. The cause is almost always one of the three critical boot configuration steps. Boot back into the live USB, mount your partitions, `arch-chroot /mnt`, and check the following:

*   **Issue: fstab Configuration**
    *   **Symptom:** System boots to an emergency shell; `/home` or other partitions are not mounted.
    *   **Check:** `cat /etc/fstab`
    *   **Fix:** Ensure your BTRFS lines use `subvol=@` and `subvol=@home`, and that any `subvolid=` entries have been removed.

*   **Issue: GRUB Kernel Parameters**
    *   **Symptom:** GRUB menu appears, but after selecting Ubuntu, you see an error like "Unable to find root device."
    *   **Check:** `cat /boot/grub/grub.cfg | grep "linux /boot/vmlinuz"`
    *   **Fix:** Ensure the output contains `root=UUID=...` and `rootflags=subvol=@`. If not, correct `/etc/default/grub` and run `update-grub` again.

*   **Issue: Initramfs Modules**
    *   **Symptom:** Boot fails with a kernel panic, often mentioning "VFS: Unable to mount root fs on unknown-block(0,0)".
    *   **Check:** `lsinitramfs /boot/initrd.img-$(uname -r) | grep btrfs` (run `uname -r` in the chroot to get the correct kernel version).
    *   **Fix:** Ensure `btrfs` (and `nvme` if needed) is listed in `/etc/initramfs-tools/modules`, then run `update-initramfs -u -k all` again.
