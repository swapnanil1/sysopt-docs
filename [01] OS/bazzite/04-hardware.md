# Step 4 — Hardware (GPU tool, fans)

## What this step is

Almost everything hardware-related is **already in Bazzite**: graphics drivers (Mesa/RADV, including 32-bit for games), audio (PipeWire with realtime priority), Bluetooth, MangoHud (the FPS overlay), gamescope, vkBasalt, `umu`, sensors tools. You install nothing for those.

What is missing is **LACT** — the app that shows GPU temperatures and lets you set a fan curve and a power limit (the replacement for CoreCtrl from the Arch guide). Bazzite used to ship it and no longer does.

## 1. Install LACT

Pick one:

```bash
# A) Flatpak, from the Bazaar app store or:
flatpak install -y flathub io.github.ilya_zlobintsev.LACT
# B) or as a system package ("layered" onto the image; needs a reboot):
sudo rpm-ostree install --enablerepo=terra lact
sudo systemctl enable lactd.service
```

Try A first; it is simpler. If LACT opens but says it cannot connect to its service, use B.

## 2. Unlock fan-curve editing (RDNA 3 / RDNA 4 cards, e.g. RX 7000 / RX 9000)

On these cards even a custom fan curve needs a kernel setting called "OverDrive" turned on. Bazzite turns it on automatically only for handheld PCs, so on a desktop card you add it yourself. This command computes the right value for *your* card and records it as a kernel argument (a boot-time switch that Bazzite keeps across updates):

```bash
sudo rpm-ostree kargs --append-if-missing="$(printf 'amdgpu.ppfeaturemask=0x%x' "$(( $(cat /sys/module/amdgpu/parameters/ppfeaturemask) | 0x4000 ))")"
```

It takes effect after a reboot. You can wait and reboot together with Step 7 (kernel args) — one reboot for both. LACT's own "Enable Overclocking" button does the same thing if you prefer clicking.

## 3. Case and AIO fans (optional): CoolerControl

```bash
ujust install-coolercontrol install      # Bazzite's recipe; installs as a layered package, reboot afterwards
```

## Audio and Bluetooth

Nothing to do. If you want microphone noise suppression, the PipeWire filter from the Arch guide's extras works unchanged here: copy the file into `~/.config/pipewire/pipewire.conf.d/` and install the plugin with `sudo rpm-ostree install noise-suppression-for-voice` (reboot).

Background: [notes §4](./99-notes.md#4-hardware).
