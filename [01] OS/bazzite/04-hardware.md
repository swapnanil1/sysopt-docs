# 4 — Hardware

Already in the image, nothing to install: Mesa/RADV (+32-bit), PipeWire + rtkit, MangoHud, vkBasalt, gamescope + ScopeBuddy, umu, ntsync autoload, input-remapper, lm_sensors, btop, fastfetch, duf.

## LACT (fan curve / power limit / monitoring) — not shipped any more

```bash
# A) Flatpak (Bazaar or:)
flatpak install -y flathub io.github.ilya_zlobintsev.LACT
# B) layer the Terra RPM (0.10.x, reboot required)
sudo rpm-ostree install --enablerepo=terra lact && sudo systemctl enable lactd.service
```

RDNA3/RDNA4 fan curves and clocks need amdgpu OverDrive. Bazzite only adds it on handhelds; on a desktop card add it yourself (LACT's "Enable Overclocking" button does the same):

```bash
sudo rpm-ostree kargs --append-if-missing="$(printf 'amdgpu.ppfeaturemask=0x%x' "$(( $(cat /sys/module/amdgpu/parameters/ppfeaturemask) | 0x4000 ))")"
```

(Reboot — batch it with [07-kargs](./07-kargs.md).)

## CoolerControl (case / AIO fans)

```bash
ujust install-coolercontrol install      # layers the RPMs; reboot
```

## Bluetooth, audio

Bluetooth is on; the image already adds `bluetooth.disable_ertm=1`. Audio threads already get realtime priority via rtkit. Mic noise suppression: the Arch guide's PipeWire filter-chain works unchanged under `~/.config/pipewire/pipewire.conf.d/` (RNNoise plugin via `rpm-ostree install noise-suppression-for-voice` or skip). [notes §3](./99-notes.md#4-hardware).
