# Step 5 — The fish shell and command-line tools

## What this step is

The "shell" is the program that reads what you type in the terminal. Bazzite gives you `bash`; **fish** is friendlier (it suggests commands as you type, colours mistakes, completes file names). fish is already installed. Command-line tools (a better `ls`, a better `cat`, a fuzzy finder, …) come from **Homebrew**, which is also already installed and lives in `/home`, so updates never remove them.

## 1. Use fish in your terminal

Bazzite's recommended way is to tell the terminal app to start fish, rather than changing the system-wide login shell:

- **Konsole:** Settings → Configure Konsole → Profiles → your profile → Edit → **Command:** `/usr/bin/fish` → OK. Open a new tab: the prompt looks different and typing `ls` shows a grey suggestion. That is fish.
- **Ptyxis** (the DX terminal): Preferences → Profiles → your profile → "Use custom command" → `/usr/bin/fish`.

If you really want fish everywhere, including the text console (this also persists across updates):

```bash
chsh -s /usr/bin/fish     # asks for your password; applies at next login
```

## 2. Install the tools

```bash
brew install eza bat fd ripgrep fzf zoxide neovim starship tealdeer dust jq doggo
```

What they are: `eza` (nicer `ls`), `bat` (nicer `cat`), `fd` (nicer `find`), `ripgrep` (`rg`, fast text search), `fzf` (fuzzy search in history and files), `zoxide` (`z folder` jumps to folders you use), `neovim` (editor), `starship` (prompt), `tealdeer` (`tldr` = short examples for any command), `dust` (disk usage), `jq` (JSON), `doggo` (DNS lookups).

Or Bazzite's own curated set in one go (`atuin`, `bat`, `eza`, `fd`, `rg`, `starship`, `zoxide`, …): `SHELL=fish ujust bazzite-cli`.

## 3. fish configuration

Create the folder and file, paste the block, save (`Ctrl+O`, `Enter`, `Ctrl+X`):

```bash
mkdir -p ~/.config/fish
nano ~/.config/fish/config.fish
```

```fish
set -gx EDITOR nvim
set -gx VISUAL nvim
fish_add_path -g ~/.local/bin
fish_add_path -g ~/.config/composer/vendor/bin      # laravel (Step 2)
if status is-interactive
    set -g fish_greeting                            # no welcome message
    # abbreviations: type the short word, press Space, it expands to the full command
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
    type -q fzf;    and fzf --fish | source          # Ctrl+R = search history, Ctrl+T = find files
    type -q zoxide; and zoxide init fish | source    # `z name` jumps to a folder you've used
end
```

Open a new terminal tab; `ls` now shows icons and `Ctrl+R` searches your history.

## Good to know

- Homebrew's programs are placed at the *end* of your PATH, so a program that exists in both Bazzite and brew runs the Bazzite one. `type -a nvim` shows which copy runs.
- Want zsh instead of fish: `brew install zsh`, then set it in the terminal profile the same way.

Background: [notes §5](./99-notes.md#5-shell).
