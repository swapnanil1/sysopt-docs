## Ubuntu Minimal Install Guide (debootstrap + BTRFS)

This guide walks you through a manual, minimal installation of Ubuntu using the command line tools from a live Ubuntu Desktop session. This method provides maximum control over your system's configuration, particularly for creating a BTRFS filesystem with subvolumes.

**Target:** Ubuntu (Latest Development Branch - "Plucky Puffin" )
**Method:** `debootstrap` and `arch-install-scripts`
**Filesystem:** BTRFS with `@` and `@home` subvolumes on an EFI system.

---

### Prerequisites

1.  **Ubuntu Desktop Live ISO:** Download the latest version and create a bootable USB drive.
2.  **Internet Connection:** Required for downloading packages.
3.  **Target Machine:** A computer with UEFI firmware.
4.  **Basic Linux CLI knowledge:** Familiarity with partitioning and command-line operations is assumed.

---

### Step 1: Boot and Prepare the Live Environment

1.  Boot your computer from the Ubuntu Live USB. Select **"Try Ubuntu"**.
2.  Connect to the internet (wired or wireless).
3.  Open a terminal (Ctrl+Alt+T).
4.  Switch to the root user to avoid typing `sudo` for every command:
    ```bash
    sudo -i
    ```
5.  Update the package list and install the necessary tools for the installation:
    ```bash
    apt update
    apt install -y debootstrap arch-install-scripts
    ```

---

### Step 2: Disk Partitioning ( `parted` )

Identify your target disk (e.g., `/dev/nvme0n1`). **WARNING: The following commands will erase all data on the disk.**

1.  **Zap old partition tables (optional but recommended):**
    ```bash
    gdisk /dev/nvme0n1
    ```
    Inside `gdisk`, press `x` (expert menu), then `z` (zap), and confirm with `y`.

2.  **Create new partitions with `parted`:**
    ```bash
    parted -s /dev/nvme0n1 -- \
      mklabel gpt \
      mkpart EFI fat32 1MiB 513MiB \
      set 1 esp on \
      mkpart "Ubuntu" btrfs 513MiB 100%
    ```

3.  **Verify the new layout:**
    ```bash
    parted /dev/nvme0n1 print
    ```
---

### Step 3: Formatting and Creating BTRFS Subvolumes

1.  **Format the EFI partition** as FAT32.
    ```bash
    mkfs.fat -F 32 -n EFI /dev/nvme0n1p1
    ```

2.  **Format the main partition** as BTRFS. Using a label is good practice.
    ```bash
    mkfs.btrfs -L Ubuntu /dev/nvme0n1p2
    ```

3.  **Create BTRFS subvolumes.** This is the core of our custom layout.
    *   First, mount the top-level BTRFS volume to a temporary location.
        ```bash
        mount /dev/nvme0n1p2 /mnt
        ```
    *   Create the subvolumes for root (`@`) and home (`@home`).
        ```bash
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        ```
    *   Unmount the temporary top-level volume.
        ```bash
        umount /mnt
        ```

---

### Step 4: Mounting Filesystems for Installation

Now, we mount the subvolumes to their final destinations. This is a critical step.

1.  **Mount the root subvolume (`@`)** to `/mnt`. We'll add some recommended BTRFS mount options.
    ```bash
    mount -o noatime,compress=zstd,ssd,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt
    ```

2.  **Create mount points** for other partitions inside the new root.
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

5.  **Verify the mounts.** Your layout should look like this:
    ```bash
    lsblk -f
    # Or for a tree view:
    findmnt -R /mnt
    ```

---

### Step 5: Install the Base System with Debootstrap

1.  Use `debootstrap` to install the base Ubuntu system into `/mnt`. We use `plucky` for the 25.04 development release codename. For a stable install, you would use `mantic` (23.10) or `jammy` (22.04 LTS).
    ```bash
    debootstrap --arch=amd64 plucky /mnt
    ```
    This will take some time as it downloads the base packages.

---

### Step 6: Chroot and Configure the New System

Now we will chroot into our new system to configure it.

1.  **Generate the fstab.** Use `genfstab` from `arch-install-scripts`.
    ```bash
    genfstab -U /mnt >> /mnt/etc/fstab
    ```

2.  **IMPORTANT: Verify and Edit fstab.** `genfstab` is good, but not perfect for BTRFS subvolumes. It sometimes adds `subvolid` which can conflict with the clearer `subvol=@` syntax, especially with GRUB. Let's fix it.
    *   Open the file: `vim /mnt/etc/fstab` (or `nano`).
    *   Ensure your BTRFS lines look like this, using `subvol=` and removing any `subvolid=` entries. The options should match what we used in the `mount` command.

    ```fstab
    # Example /etc/fstab
    # <file system>                             <mount point>  <type>  <options>                                                              <dump> <pass>
    UUID=YOUR_EFI_UUID                          /boot/efi      vfat    umask=0077                                                             0      1
    UUID=YOUR_BTRFS_PARTITION_UUID              /              btrfs   rw,noatime,compress=zstd,ssd,space_cache=v2,subvol=@                   0      0
    UUID=YOUR_BTRFS_PARTITION_UUID              /home          btrfs   rw,noatime,compress=zstd,ssd,space_cache=v2,subvol=@home               0      0
    ```
    *   You can get the UUIDs again with `blkid`.

3.  **Chroot into the new system.** `arch-chroot` handles mounting `/dev`, `/proc`, `/sys` for you.
    ```bash
    arch-chroot /mnt
    ```

4.  **Configure APT Sources.** The base system has a minimal sources list. Let's add the `universe`, `multiverse`, and `restricted` repositories.
    *   Open `/etc/apt/sources.list` with an editor (`apt install -y nano vim`).
    *   Add the other components to your main deb lines. It should look something like this:
        ```sources.list
        deb http://archive.ubuntu.com/ubuntu/ plucky main restricted universe multiverse

        deb http://archive.ubuntu.com/ubuntu/ plucky-updates main restricted universe multiverse

        deb http://archive.ubuntu.com/ubuntu/ plucky-backports main restricted universe multiverse

        deb http://security.ubuntu.com/ubuntu/ plucky-security main restricted universe multiverse
        ```
    *   Update the package list again from within the chroot:
        ```bash
        apt update
        ```

5.  **Install Core Packages.** This includes the kernel, firmware, networking, filesystem tools, and a minimal desktop.
    ```bash
    apt install --no-install-recommends -y \
      linux-generic \
      linux-firmware \
      initramfs-tools \
      btrfs-progs \
      grub-efi-amd64 \
      efibootmgr \
      network-manager \
      zstd aria2c \
      ubuntu-desktop ubuntu-restricted-extras \
      gvfs-backends yaru-theme-icon yaru-theme-gtk loupe mpv
    ```
    *   `--no-install-recommends` keeps the installation leaner.

6.  **PREVENTATIVE FIX 1: Configure Initramfs.** To prevent a "cannot mount root" kernel panic, we must ensure the `btrfs` and `nvme` (if using an NVMe drive) modules are loaded early.
    ```bash
    echo "btrfs" >> /etc/initramfs-tools/modules
    echo "nvme" >> /etc/initramfs-tools/modules  # Add this if you are on an NVMe drive
    ```

7.  **PREVENTATIVE FIX 2: Configure GRUB.** We need to tell GRUB how to find our root subvolume.
    *   Find the UUID of your BTRFS partition (`/dev/nvme0n1p2` in our example):
        ```bash
        blkid | grep "nvme0n1p2"
        ```
    *   Edit the GRUB default configuration file: `vim /etc/default/grub`.
    *   Find the `GRUB_CMDLINE_LINUX` line and modify it to include the `root` UUID and `rootflags=subvol=@`.
        ```grub
        # Example line
        GRUB_CMDLINE_LINUX="root=UUID=YOUR_BTRFS_PARTITION_UUID rootflags=subvol=@"
        ```
    *   **Do not** modify `GRUB_CMDLINE_LINUX_DEFAULT`.

8.  **Configure System Basics.**
    *   Set timezone, locale, and keyboard layout:
        ```bash
        dpkg-reconfigure tzdata
        dpkg-reconfigure locales
        dpkg-reconfigure keyboard-configuration
        ```
    *   Set the hostname:
        ```bash
        echo "my-ubuntu" > /etc/hostname
        echo "127.0.0.1 localhost my-ubuntu" >> /etc/hosts
        ```
    *   Enable NetworkManager for networking after reboot:
        ```bash
        systemctl enable NetworkManager
        ```
    *   Create a user account and set a password:
        ```bash
        useradd -m -G sudo,audio,video,input -s /bin/bash yourusername
        passwd yourusername
        ```
    *   Set a password for the root user (recommended):
        ```bash
        passwd
        ```

9.  **Install and Update the Bootloader and Initramfs.** This is the final and most critical step. The changes we made to GRUB and initramfs will now be applied.
    *   Install GRUB to the EFI partition:
        ```bash
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
        ```
    *   Generate the GRUB configuration file:
        ```bash
        update-grub
        ```
    *   Update the initial RAM filesystem for all installed kernels:
        ```bash
        update-initramfs -u -k all
        ```

---

### Step 7: Finalize and Reboot

1.  **Exit the chroot** environment.
    ```bash
    exit
    ```
2.  **Unmount all partitions** in reverse order.
    ```bash
    umount -R /mnt
    ```
3.  **Reboot the system.**
    ```bash
    reboot
    ```
    Remove the installation media when prompted. Your new minimal Ubuntu system should now boot from the hard drive.

---

### Post-Install Verification & Troubleshooting

If you encounter issues (like a kernel panic or being dropped into an `initramfs` shell), it's almost always due to one of the three critical configuration steps. Here’s how to check them from a live USB environment if needed (by chrooting back in):

*   **Check `fstab`:** `cat /etc/fstab`
    *   *Symptom:* System boots but home directory isn't mounted or you get emergency mode.
    *   *Fix:* Ensure `subvol=@` and `subvol=@home` are correctly specified and there's no `subvolid`.

*   **Check GRUB Kernel Parameters:** `cat /boot/grub/grub.cfg | grep "UUID"`
    *   *Symptom:* GRUB loads but then fails with "Unable to find root device".
    *   *Fix:* Verify that `root=UUID=...` and `rootflags=subvol=@` are present. If not, fix `/etc/default/grub` and run `update-grub` again in the chroot.

*   **Check Initramfs Modules:** `lsinitramfs /boot/initrd.img-$(uname -r) | grep -E 'btrfs|nvme'` (run `uname -r` in the chroot to get the correct kernel version).
    *   *Symptom:* Kernel panic, "VFS: Unable to mount root fs on unknown-block(0,0)".
    *   *Fix:* Add `btrfs` and `nvme` to `/etc/initramfs-tools/modules` and run `update-initramfs -u -k all` again in the chroot.
