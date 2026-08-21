# 2 — CachyOS repositories

```bash
/lib/ld-linux-x86-64.so.2 --help | grep supported      # need: x86-64-v3 (supported, searched)
curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
sudo ./cachyos-repo.sh          # imports key, installs CachyOS pacman + mirrorlists, inserts repos ABOVE [core], runs pacman -Syu
```

`sudoedit /etc/pacman.conf`:

```ini
[options]
Color
ILoveCandy
VerbosePkgLists
ParallelDownloads = 5

[multilib]                      # uncomment both — needed for steam / lib32-*
Include = /etc/pacman.d/mirrorlist
```

Mirrors + cache:

```bash
sudo pacman -S --needed cachyos-rate-mirrors pacman-contrib   # ranks Arch AND CachyOS mirrors; never install reflector
sudo cachyos-rate-mirrors
sudo systemctl enable --now cachyos-rate-mirrors.timer paccache.timer
echo "PACCACHE_ARGS='-k2'" | sudo tee -a /etc/conf.d/pacman-contrib
```

Repo order beats version number (by design). Why it matters: [notes §2](./99-notes.md#2-cachyos-repos).
