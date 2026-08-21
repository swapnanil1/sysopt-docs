# Extras

## DNS-over-TLS (systemd-resolved)

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dns_over_tls.conf >/dev/null <<'EOF'
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net
#DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
DNSOverTLS=yes
DNSSEC=no
Domains=~.
EOF
sudo systemctl restart systemd-resolved && resolvectl status | grep -E 'DNS Servers|Protocols'
```

## Mic noise suppression (RNNoise)

```bash
sudo pacman -S --needed noise-suppression-for-voice
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/99-input-denoising.conf <<'EOF'
context.modules = [
    {   name = libpipewire-module-filter-chain
        flags = [ nofail ]
        args = {
            node.description = "Noise Canceling source"
            media.name       = "Noise Canceling source"
            filter.graph = {
                nodes = [
                    {   type = ladspa
                        name = rnnoise
                        plugin = "librnnoise_ladspa"
                        label  = noise_suppressor_mono
                        control = { "VAD Threshold (%)" = 50.0  "VAD Grace Period (ms)" = 200  "Retroactive VAD Grace (ms)" = 0 }
                    }
                ]
            }
            capture.props  = { node.name = "capture.rnnoise_source"  node.passive = true  audio.rate = 48000  audio.channels = 1  audio.position = [ MONO ] }
            playback.props = { node.name = "rnnoise_source"  media.class = Audio/Source  audio.rate = 48000  audio.channels = 1  audio.position = [ MONO ] }
        }
    }
]
EOF
systemctl --user restart pipewire.service     # then pick "Noise Canceling source" as input
```

## Android (ADB)

```bash
sudo pacman -S --needed android-tools android-udev && sudo usermod -aG adbusers "$USER"   # re-login; adb devices
```
