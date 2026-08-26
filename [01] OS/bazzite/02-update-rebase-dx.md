# 2 — Update, then rebase to Bazzite DX

**What this does.** Brings the image to today's version, then switches it to the "DX" variant (same Bazzite plus developer tools). A rebase is not a reinstall: it downloads a different image and makes it your next deployment; your files and settings stay. fstab came first only because it is a disk-table change that survives any image switch; from here on, every tweak is made once, on the image you'll actually keep.

DX = the same image plus Docker (ready to use), VS Code with devcontainers and the container-centric Ptyxis terminal. Same KDE, same kernel; everything in this guide applies unchanged. Do this before any other step so the tweaks land once, on the image you keep.

```bash
ujust update && systemctl reboot                     # bring the base image current first
rpm-ostree status                                    # note the flavor (bazzite:stable) and that the update is booted
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable   # KDE + AMD/Intel; NVIDIA: bazzite-dx-nvidia; GNOME: bazzite-dx-gnome
systemctl reboot
rpm-ostree status                                    # ● ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable
```

(`brh rebase bazzite-dx:stable` is the same rebase through Bazzite's helper.) Rebasing keeps `/etc`, `/var`, kargs and layers — it is a normal deployment switch. Never rebase across desktops (KDE ↔ GNOME is unsupported).

## Docker

```bash
ujust --choose | grep -i dx                          # DX images ship `ujust dx-group` (adds you to docker); if absent:
sudo usermod -aG docker "$USER"                      # re-login; docker group = passwordless root, same as everywhere
docker run --rm hello-world
```

## Web-dev toolchain — Homebrew, nothing layered

```bash
brew install node go php composer
composer global require laravel/installer
fish_add_path -g ~/.config/composer/vendor/bin       # `laravel new app`; bash: export PATH="$HOME/.config/composer/vendor/bin:$PATH" in ~/.bashrc
node -v && npm -v && go version && php -v && laravel --version
```

Databases and services (MySQL/Postgres/Redis/Mailpit) run as containers — `docker compose` per project, or Laravel Sail (`composer require laravel/sail --dev`). Version pinning: `brew install node@22` / `php@8.3` (keg-only; `brew link --overwrite --force node@22`), or a devcontainer per project in VS Code. Go and PHP brew packages are Linux-native builds; brew binaries sit at the end of `PATH`, so `type -a php` shows which one runs. [notes §2](./99-notes.md#2-update--dx).
