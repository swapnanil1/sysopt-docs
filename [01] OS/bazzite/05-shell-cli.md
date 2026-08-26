# 5 — Shell & CLI

`fish` is an RPM in the image and Homebrew (`/home/linuxbrew/.linuxbrew`) is preinstalled and already initialised for bash and fish.

```bash
# Bazzite's recommended way: set the shell per terminal profile (Konsole → profile → Command: /usr/bin/fish), not system-wide
# If you want it as the login shell anyway (persists; /etc/passwd lives in /etc):
chsh -s /usr/bin/fish

# CLI tools via Homebrew (never layer these)
brew install eza bat fd ripgrep fzf zoxide neovim starship tealdeer dust jq doggo
# or Bazzite's curated set (atuin, bat, eza, fd, rg, starship, zoxide, …):
SHELL=fish ujust bazzite-cli
```

`~/.config/fish/config.fish` — same as the Arch guide minus the pacman abbreviations:

```fish
set -gx EDITOR nvim
set -gx VISUAL nvim
fish_add_path -g ~/.local/bin
if status is-interactive
    set -g fish_greeting
    abbr -a update  'ujust update'
    abbr -a rs      'rpm-ostree status'
    abbr -a fi      'flatpak install flathub'
    abbr -a fu      'flatpak uninstall'
    if type -q eza
        alias ls  'eza --group-directories-first --icons=auto'
        alias ll  'eza -l --group-directories-first --icons=auto --git'
        alias la  'eza -la --group-directories-first --icons=auto --git'
    end
    type -q bat;    and alias cat 'bat --paging=never'
    type -q fzf;    and fzf --fish | source
    type -q zoxide; and zoxide init fish | source
end
```

zsh: `brew install zsh` and set it in the terminal profile (not in the image). Homebrew binaries sit at the *end* of `PATH` so system tools win — `type -a nvim` shows which one you run. [notes §4](./99-notes.md#5-shell).
