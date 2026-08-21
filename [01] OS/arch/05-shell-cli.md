# 5 — Shell, AUR helper, CLI tools

```bash
sudo pacman -S --needed fish && chsh -s /usr/bin/fish       # your user only; never root's shell
sudo pacman -S --needed paru                                   # [cachyos] binary — no makepkg
sudo pacman -S --needed man-db man-pages git rsync openssh eza bat fd ripgrep fzf zoxide btop usbutils lm_sensors wl-clipboard
sudo pacman -S --needed fastfetch duf dust tealdeer jq doggo mtr dmidecode wget && tldr --update
sudo sensors-detect
sudo pacman -S --needed neovim tree-sitter-cli lazygit      # LazyVim needs tree-sitter-cli; not pynvim/nodejs
```

`~/.config/fish/config.fish`:

```fish
set -gx EDITOR nvim
set -gx VISUAL nvim
fish_add_path -g ~/.local/bin
if status is-interactive
    set -g fish_greeting
    abbr -a update  'sudo pacman -Syu && paru -Sua'
    abbr -a pi      'sudo pacman -S --needed'
    abbr -a prs     'sudo pacman -Rns'
    abbr -a ps      'pacman -Ss'
    abbr -a pq      'pacman -Qs'
    abbr -a orphans 'sudo pacman -Rns (pacman -Qtdq)'
    abbr -a pa      'paru -S'
    abbr -a vim     nvim
    if type -q eza
        alias ls  'eza --group-directories-first --icons=auto'
        alias ll  'eza -l --group-directories-first --icons=auto --git'
        alias la  'eza -la --group-directories-first --icons=auto --git'
        alias lt  'eza --tree --level=2 --icons=auto'
    end
    type -q bat;    and alias cat 'bat --paging=never'
    type -q fzf;    and fzf --fish | source
    type -q zoxide; and zoxide init fish | source
end
```

`~/.config/paru/paru.conf`:

```ini
[options]
PgpFetch
Devel
Provides
DevelSuffixes = -git -cvs -svn -bzr -darcs -always -hg -fossil
BottomUp
SudoLoop
CleanAfter
RemoveMake = ask
NewsOnUpgrade
UpgradeMenu
#SkipReview        # FAST: no PKGBUILD review. Not recommended even here.
```

LazyVim (optional):

```bash
mv ~/.config/nvim{,.bak}; mv ~/.local/share/nvim{,.bak}; mv ~/.local/state/nvim{,.bak}; mv ~/.cache/nvim{,.bak}
git clone https://github.com/LazyVim/starter ~/.config/nvim && rm -rf ~/.config/nvim/.git && nvim
```

zsh instead of fish: `zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions`, config in [notes §5](./99-notes.md#5-shell).
