# Step 2 — Update, then switch ("rebase") to Bazzite DX

## What this step is

Two things:

1. **Update** to today's version of Bazzite. Updates on Bazzite download a whole new copy of the system in the background and switch to it when you reboot — nothing changes while you are logged in.
2. **Rebase to DX.** "Rebase" means: keep everything that is yours (files, settings, Flatpaks, the fstab you just edited) but take the system image from a different source. `bazzite-dx` is the same Bazzite plus developer tools: **Docker** ready to use, **VS Code** with devcontainers, and the Ptyxis terminal. Same desktop, same kernel — every later step of this guide works exactly the same.

This is not a reinstall. It is the same mechanism as an update, pointed at a different image name.

## 1. Update and reboot

```bash
ujust update          # `ujust` = Bazzite's menu of helper commands; this one updates the system, Flatpaks and brew
systemctl reboot
```

After the reboot, open Konsole again and check that you are on the new version:

```bash
rpm-ostree status
```

The first entry (marked `●`) is the system you are running. Its line should say `bazzite:stable` and show today's date-like version number.

## 2. Rebase to DX and reboot

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable
```

(This is the KDE + AMD image. NVIDIA card: `bazzite-dx-nvidia`. GNOME desktop: `bazzite-dx-gnome` — but never switch between KDE and GNOME with a rebase; that is unsupported.) It downloads a few GB and then says to reboot:

```bash
systemctl reboot
rpm-ostree status
```

The `●` entry should now read `ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable`. Your fstab, your files and everything under `/etc` came along — you can check with `cat /etc/fstab`.

Same thing through Bazzite's own helper, if you prefer: `brh rebase bazzite-dx:stable`.

## 3. Docker

Docker is installed, but your user needs permission to use it:

```bash
ujust --choose | grep -i dx      # DX images normally ship a "dx-group" recipe that adds you to the docker group
ujust dx-group                   # if the line above listed it; otherwise run the next command instead
sudo usermod -aG docker "$USER"  # the manual way (same result)
```

Log out and back in (group changes apply at login), then test:

```bash
docker run --rm hello-world      # prints "Hello from Docker!"
```

Being in the `docker` group is equivalent to having root on the machine — normal for a personal computer, just so you know.

## 4. Web-development tools (node, npm, PHP, Laravel, Go)

On Bazzite, command-line tools are installed with **Homebrew** (`brew`). It is already installed and lives inside `/home`, so updates never touch it and nothing is "layered" onto the system.

```bash
brew install node go php composer
composer global require laravel/installer
```

`laravel` gets installed into `~/.config/composer/vendor/bin`, which is not on your PATH yet. Add it (this also goes into your fish config in Step 5 — running it here is enough, it is remembered):

```bash
fish_add_path -g ~/.config/composer/vendor/bin
```

(If you are still using bash instead of fish: add `export PATH="$HOME/.config/composer/vendor/bin:$PATH"` to `~/.bashrc`.)

Check that everything answers:

```bash
node -v && npm -v && go version && php -v && laravel --version
```

Notes for later:
- Databases (MySQL, Postgres, Redis, Mailpit) run as containers: a `docker compose` file per project, or Laravel Sail (`composer require laravel/sail --dev`).
- A specific version: `brew install node@22` or `php@8.3`, then `brew link --overwrite --force node@22` to make it the default — or use a devcontainer per project in VS Code.
- `type -a php` shows which php runs if you ever have two.

Background: [notes §2](./99-notes.md#2-update--dx).
