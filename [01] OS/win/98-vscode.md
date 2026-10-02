# Dev Setup From Zero: Windows + Scoop + Git Bash + VS Code (JS/TS)

A calm, big-text setup for learning JavaScript and TypeScript by hand, frontend and backend.

Do the steps in order. Each one ends with a **Check** so you know it worked before moving on. You can stop after any step and come back later.

| Step | What | Time |
|---|---|---|
| 1 | Install Scoop | 2 min |
| 2 | Install the tools and the font | 5 min |
| 3 | Install VS Code extensions | 2 min |
| 4 | Paste VS Code settings | 3 min |
| 5 | Three clicks VS Code has no setting for | 1 min |
| 6 | Git basics | 1 min |
| 7 | Git Bash: prompt, aliases, history search | 5 min |
| 8 | Global JS tools: Biome, TypeScript, tsx | 1 min |
| 9 | How the Biome config works (`biomehere`) | 2 min |
| 10 | Start a project with `newproj` | 1 min |

Last checked 2026-10-02 with VS Code 1.140, Node 26.10, TypeScript 7.0.2, Biome 2.5.15, Git 2.56. Section 15 lists what was tested and what was not.

---

## 1. Install Scoop

Open **PowerShell** (not as admin) and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

**Check:** `scoop --version` prints a version.

## 2. Install the tools and the font

Still in PowerShell:

```powershell
scoop install git
scoop bucket add extras
scoop bucket add nerd-fonts
scoop install vscode nodejs JetBrains-Mono
scoop install zoxide fzf bat eza tealdeer gh ripgrep
```

| Tool | What it gives you |
|---|---|
| `git` | Git and Git Bash |
| `vscode` | the editor |
| `nodejs` | Node 26, which runs `.js` and `.ts` files directly |
| `JetBrains-Mono` | the font |
| `zoxide` | `z proj` jumps to a folder you have visited before |
| `fzf` | Ctrl+R becomes a fuzzy search through your command history |
| `bat` | `cat` with syntax colors |
| `eza` | a clearer `ls` |
| `tealdeer` | `tldr tar` shows short examples for any command |
| `gh` | GitHub from the terminal |
| `ripgrep` | `rg text` searches file contents fast |

**Check:** close PowerShell, open a new one, and run `node --version; code --version; git --version`.

Update everything later with `scoop update *`.

## 3. Install VS Code extensions

Open **Git Bash** and paste:

```bash
code --install-extension biomejs.biome
code --install-extension usernamehw.errorlens
code --install-extension yoavbls.pretty-ts-errors
code --install-extension Orta.vscode-twoslash-queries
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension formulahendry.code-runner
code --install-extension miguelsolorio.symbols
code --install-extension miguelsolorio.fluent-icons
```

Each line is a complete command, so you can also paste them one at a time. Copy only the commands, never the prompt lines above them.

| Extension | Why |
|---|---|
| Biome | lint, format and sort imports, in one tool |
| Error Lens | shows the error text on the line itself, so no hovering |
| Pretty TypeScript Errors | turns long TS errors into readable ones |
| Twoslash Query Comments | type `//  ^?` under a name to see its type inline |
| Code Spell Checker | catches typos in names |
| Code Runner | the ▶ Run button, top right of the editor |
| Symbols | simple, flat file icons |
| Fluent Icons | cleaner icons for VS Code's own buttons |

All are free with no paid tier.

Add these later, when you reach the topic:

| When | Extension | ID |
|---|---|---|
| Building an HTML/CSS page | Live Preview | `ms-vscode.live-server` |
| Building a backend API | REST Client | `humao.rest-client` |
| Writing tests | Vitest | `vitest.explorer` |
| Using Tailwind | Tailwind CSS IntelliSense | `bradlc.vscode-tailwindcss` |
| Using branches a lot | Git Graph | `mhutchie.git-graph` |

**Check:** `code --list-extensions` shows the eight IDs.

## 4. Paste VS Code settings

In VS Code press Ctrl+Shift+P, run **Preferences: Open User Settings (JSON)**, and replace the contents with this:

```jsonc
{
    // ---------- Quiet: no pop-ups, no telemetry ----------
    "workbench.startupEditor": "none",
    "workbench.editor.empty.hint": "hidden",
    "workbench.tips.enabled": false,
    "update.showReleaseNotes": false,
    "extensions.ignoreRecommendations": true,
    "terminal.integrated.initialHint": false,
    "telemetry.telemetryLevel": "off",
    "telemetry.feedback.enabled": false,
    "telemetry.editStats.enabled": false,
    "chat.titleBar.signIn.enabled": false,
    "chat.titleBar.openInAgentsWindow.enabled": false,

    // ---------- Replit-style layout: files left, code middle, terminal right ----------
    "workbench.activityBar.location": "top",
    "window.menuBarVisibility": "compact",
    "window.commandCenter": true,
    "workbench.layoutControl.enabled": false,
    "workbench.navigationControl.enabled": false,
    "workbench.panel.defaultLocation": "right",
    "workbench.panel.showLabels": false,
    "workbench.iconTheme": "symbols",
    "workbench.productIconTheme": "fluent-icons",

    // ---------- Big, readable text ----------
    "window.zoomLevel": 1,
    "editor.fontFamily": "'JetBrains Mono', Consolas, monospace",
    "editor.fontSize": 17,
    "editor.lineHeight": 1.6,
    "editor.wordWrap": "on",
    "terminal.integrated.fontFamily": "'JetBrains Mono', Consolas, monospace",
    "terminal.integrated.fontSize": 16,
    "terminal.integrated.lineHeight": 1.2,

    // ---------- Calm editor ----------
    "editor.minimap.enabled": false,
    "editor.stickyScroll.enabled": true,
    "editor.linkedEditing": true,
    "editor.guides.bracketPairs": "active",
    "editor.bracketPairColorization.independentColorPoolPerBracketType": true,
    "editor.inlineSuggest.enabled": false,
    "workbench.editor.limit.enabled": true,
    "workbench.editor.limit.value": 5,
    "explorer.compactFolders": false,
    "workbench.tree.indent": 16,
    "explorer.fileNesting.enabled": true,
    "explorer.fileNesting.patterns": {
        "package.json": "package-lock.json, pnpm-lock.yaml, tsconfig.json, biome.json"
    },

    // ---------- Files ----------
    "files.autoSave": "afterDelay",
    "files.eol": "\n",
    "files.insertFinalNewline": true,
    "files.trimTrailingWhitespace": true,

    // ---------- Errors on the line (Error Lens) ----------
    "errorLens.delay": 500,
    "errorLens.enabledDiagnosticLevels": ["error", "warning"],
    "errorLens.messageMaxChars": 120,

    // ---------- Biome: format + lint + sort imports ----------
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "biomejs.biome",
    "editor.codeActionsOnSave": {
        "source.fixAll.biome": "explicit",
        "source.organizeImports.biome": "explicit"
    },

    // ---------- JS/TS hints ----------
    "js/ts.implicitProjectConfig.checkJs": true,
    "js/ts.inlayHints.parameterNames.enabled": "literals",
    "js/ts.inlayHints.variableTypes.enabled": true,
    "js/ts.inlayHints.functionLikeReturnTypes.enabled": true,
    "js/ts.updateImportsOnFileMove.enabled": "always",
    "js/ts.suggest.autoImports": true,
    "js/ts.suggest.completeFunctionCalls": true,

    // ---------- Terminal: Git Bash ----------
    "terminal.integrated.defaultProfile.windows": "Git Bash",
    "terminal.integrated.profiles.windows": {
        "Git Bash": {
            "path": "${env:USERPROFILE}\\scoop\\apps\\git\\current\\bin\\bash.exe",
            "args": ["--login", "-i"]
        }
    },

    // ---------- Run button (Code Runner) ----------
    "code-runner.runInTerminal": true,
    "code-runner.clearPreviousOutput": true,
    "code-runner.saveFileBeforeRun": true,
    "code-runner.saveAllFilesBeforeRun": true,
    "code-runner.ignoreSelection": true,
    "code-runner.enableAppInsights": false,
    "code-runner.executorMap": {
        "javascript": "node",
        "typescript": "node"
    }
}
```

What the less obvious lines do:

| Setting | Effect |
|---|---|
| `activityBar.location: top` | the icon strip on the far left becomes a small row above the file list |
| `menuBarVisibility: compact` | File, Edit, View and the rest collapse into one menu button |
| `window.zoomLevel: 1` | makes the whole UI bigger, including icons and the file list |
| `editor.inlineSuggest.enabled: false` | no AI ghost text, so you type the code yourself |
| `editor.limit.value: 5` | at most 5 tabs; the oldest closes itself |
| `fileNesting` | lock files, `tsconfig.json` and `biome.json` fold under `package.json` |
| `files.eol: "\n"` | new files use LF line endings, which bash needs |
| `errorLens.delay: 500` | error text waits half a second, so it does not flash while you type |

Things to know:

- **Text size:** zoom multiplies everything by about 1.2, so font size 17 looks like 20. Change `editor.fontSize` and `terminal.integrated.fontSize` to taste.
- **Formatting happens on Ctrl+S.** Auto save writes the file but does not format it.
- **Other AI features:** `"chat.disableAIFeatures": true` turns off VS Code's built-in AI features too. It is optional and not included above.
- **Schema prompt:** if VS Code asks to trust `biomejs.dev` when you open a `biome.json`, allow it. That enables autocomplete inside the file.

**Check:** open a new terminal with Ctrl+`. It should be Git Bash.

## 5. Three clicks VS Code has no setting for

1. Right-click the **Explorer** title and untick **Outline** and **Timeline**. Only the file list stays.
2. If the terminal is at the bottom, press Ctrl+Shift+P and run **View: Move Panel Right**.
3. Pick a color theme with Ctrl+K then Ctrl+T.

Free themes worth trying (install by ID from the Extensions view):

| Theme | ID |
|---|---|
| Night Owl | `sdras.night-owl` |
| Catppuccin | `Catppuccin.catppuccin-vsc` |
| GitHub Theme | `GitHub.github-vscode-theme` |

Optional: Replit-style navy colors on top of any dark theme. Add this inside your `settings.json`:

```jsonc
"workbench.colorCustomizations": {
    "editor.background": "#0E1525",
    "panel.background": "#0E1525",
    "terminal.background": "#0E1525",
    "tab.activeBackground": "#0E1525",
    "sideBar.background": "#1C2333",
    "activityBar.background": "#1C2333",
    "titleBar.activeBackground": "#1C2333",
    "statusBar.background": "#1C2333",
    "editorGroupHeader.tabsBackground": "#1C2333",
    "tab.inactiveBackground": "#1C2333",
    "editor.lineHighlightBackground": "#1C2333",
    "list.activeSelectionBackground": "#2B3245",
    "list.hoverBackground": "#2B3245",
    "sideBar.border": "#2B3245",
    "panel.border": "#2B3245",
    "focusBorder": "#0079F2",
    "button.background": "#0079F2"
}
```

These hex values approximate Replit's dark palette. Delete the block if you do not like the result.

## 6. Git basics

In Git Bash:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
git config --global core.autocrlf input
```

Skip the first two lines if you already set your identity per folder.

**Check:** `git config --global --list` shows the lines.

## 7. Git Bash: prompt, aliases, history search

You will create three files in your home folder. Create each one with `code ~/.bashrc` (and so on), paste, save.

### `~/.bash_profile`

```bash
[ -f ~/.bashrc ] && . ~/.bashrc
```

### `~/.bashrc`

```bash
# ---------- Tools (each line is skipped if the tool is not installed) ----------
command -v zoxide >/dev/null && eval "$(zoxide init bash)"   # z <part of folder name>
command -v fzf    >/dev/null && eval "$(fzf --bash)"         # Ctrl+R fuzzy history

# ---------- Aliases ----------
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias gs='git status -sb'
alias gl='git log --oneline --graph -15'
alias nw='node --watch'

if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -la --group-directories-first --git'
else
  alias ll='ls -la'
fi
command -v bat >/dev/null && alias cat='bat -pp'

# ---------- biomehere: make sure this folder is covered by a Biome config ----------
biomehere() {
  if [ -e biome.json ]; then echo "biome.json already exists here, left unchanged"; return 0; fi
  local d="$PWD"
  while [ "$d" != "/" ]; do
    d=$(dirname "$d")
    if [ -e "$d/biome.json" ]; then echo "Using the biome.json in $d"; return 0; fi
  done
  cat > biome.json <<'EOF'
{
    "$schema": "https://biomejs.dev/schemas/2.5.15/schema.json",
    "vcs": {
        "enabled": false,
        "clientKind": "git",
        "useIgnoreFile": false
    },
    "files": {
        "ignoreUnknown": true,
        "includes": ["**", "!**/package.json"]
    },
    "formatter": {
        "enabled": true,
        "indentStyle": "space",
        "indentWidth": 4
    },
    "linter": {
        "enabled": true,
        "rules": {
            "preset": "recommended",
            "correctness": {
                "noUndeclaredVariables": "error",
                "noUnusedVariables": "warn",
                "noUnusedImports": "warn",
                "noUnusedFunctionParameters": "warn"
            },
            "suspicious": {
                "noVar": "error",
                "noEmptyBlockStatements": "warn",
                "noEvolvingTypes": "warn",
                "useAwait": "warn",
                "useErrorMessage": "warn"
            },
            "style": {
                "useNamingConvention": "warn",
                "useConst": "warn",
                "useTemplate": "warn",
                "useBlockStatements": "warn",
                "useCollapsedElseIf": "warn",
                "useShorthandAssign": "warn",
                "useDefaultParameterLast": "warn",
                "useForOf": "warn",
                "useThrowOnlyError": "warn",
                "useThrowNewError": "warn",
                "noParameterAssign": "warn",
                "noNestedTernary": "warn",
                "noUselessElse": "warn",
                "noYodaExpression": "warn",
                "noNonNullAssertion": "warn",
                "noInferrableTypes": "warn"
            },
            "complexity": {
                "useSimplifiedLogicExpression": "warn",
                "noUselessStringConcat": "warn",
                "useWhile": "warn",
                "noExcessiveCognitiveComplexity": "warn"
            },
            "performance": {
                "noAccumulatingSpread": "warn",
                "noDelete": "warn"
            },
            "nursery": {
                "noFloatingPromises": "error",
                "noMisusedPromises": "error",
                "useAwaitThenable": "warn"
            }
        }
    },
    "javascript": {
        "formatter": {
            "quoteStyle": "double"
        }
    },
    "assist": {
        "enabled": true,
        "actions": {
            "source": {
                "organizeImports": "on"
            }
        }
    }
}
EOF
  echo "biome.json written"
}

# ---------- newproj <name>: a folder ready for Node + TypeScript + Biome ----------
newproj() {
  if [ -z "$1" ]; then echo "usage: newproj <name>"; return 1; fi
  mkdir -p "$1" && cd "$1" || return 1
  npm init -y >/dev/null
  npm pkg set type=module
  npm i -D @types/node
  cat > tsconfig.json <<'EOF'
{
    "compilerOptions": {
        "target": "esnext",
        "module": "nodenext",
        "lib": ["esnext", "dom"],
        "types": ["node"],
        "strict": true,
        "noUncheckedIndexedAccess": true,
        "noImplicitOverride": true,
        "noFallthroughCasesInSwitch": true,
        "verbatimModuleSyntax": true,
        "isolatedModules": true,
        "moduleDetection": "force",
        "skipLibCheck": true,
        "noEmit": true,
        "allowJs": true,
        "checkJs": true
    }
}
EOF
  biomehere
  printf 'console.log("hello from %s");\n' "$1" > index.ts
  echo "Ready. Run: node --watch index.ts"
}

# ---------- Prompt: time, folder (green = ok, red = last command failed), git branch ----------
__ps1_update() {
  local ec=$?
  if [ $ec -eq 0 ]; then __c=$'\e[32m'; else __c=$'\e[31m'; fi

  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  if [ -n "$b" ]; then __b=" ($b)"; else __b=""; fi
}
case "$PROMPT_COMMAND" in
  *__ps1_update*) ;;
  *) PROMPT_COMMAND="__ps1_update${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

export PS1='\n\[\e[2m\]\A\[\e[0m\] \[${__c}\]\W\[\e[0m\]\[\e[35m\]${__b}\[\e[0m\]\n🚀 '
```

The prompt looks like this, with a blank line before it:

```
18:35 my-app (main)
🚀
```

### `~/.inputrc`

```
$include /etc/inputrc

set completion-ignore-case on
set show-all-if-ambiguous on
set colored-stats on
set bell-style none

"\e[A": history-search-backward
"\e[B": history-search-forward
```

| Line | Effect |
|---|---|
| `completion-ignore-case` | Tab completes `doc` to `Documents` |
| `show-all-if-ambiguous` | one Tab shows all matches |
| the two arrow lines | type `git` then press Up to walk through past `git` commands only |

Then run once:

```bash
tldr --update
```

**Check:** open a new terminal. You see the two-line prompt, `ll` lists files, and `tldr ls` prints examples.

## 8. Global JS tools

```bash
npm i -g @biomejs/biome typescript tsx
```

| Command | Use |
|---|---|
| `biome` | lint and format |
| `tsc` | type check: `tsc --noEmit` |
| `tsx` | runs TS that Node cannot (`enum`, `namespace`, parameter properties) |

**Check:** `biome --version && tsc --version && tsx --version`.

## 9. Biome config: `biomehere`

Biome has no global settings store. It walks up from the file it is checking until it finds a `biome.json`, and uses that one.

You never write that file by hand. The `biomehere` function from step 7 holds the full config and does this:

| Situation | What `biomehere` does |
|---|---|
| No `biome.json` here or in any folder above | writes one here |
| A `biome.json` exists in a folder above | writes nothing and tells you which one is in use |
| A `biome.json` already exists here | leaves it alone |

`newproj` calls `biomehere` for you. Run `biomehere` yourself in a folder of loose practice files.

Two rules keep this simple:

- **One config per tree.** Biome refuses to run when a `biome.json` sits inside a folder that already has one above it. `biomehere` avoids that for you.
- **To change the rules everywhere,** edit the JSON inside `biomehere` in `~/.bashrc`. Folders that already have a `biome.json` keep their copy until you edit or delete it.

The config skips `package.json`, because npm rewrites that file in its own format and Biome would complain every time.

What the rule groups catch:

| Group | Catches |
|---|---|
| `correctness` | variables that were never declared; unused variables, imports and parameters |
| `suspicious` | `var`, empty `{}` blocks, `async` with no `await`, errors with no message |
| `style` | naming conventions, `let` that should be `const`, `if` without braces, nested ternaries |
| `complexity` | tangled boolean logic, functions that are too hard to follow |
| `performance` | spread inside a loop, `delete` on objects |
| `nursery` | a forgotten `await` (experimental rules; they can miss cases or misfire) |

Red means a likely bug. Yellow means a habit worth fixing. To silence a rule, set it to `"off"`.

**Check:** in an empty test folder, run `biomehere`, then `biome check .`.

## 10. Start a project

```bash
mkdir -p ~/code && cd ~/code
newproj my-app
code .
```

`~/code` is only an example. Use whichever folder holds your projects.

`newproj` creates the folder, `package.json` (with `"type": "module"`), Node types, `tsconfig.json`, an `index.ts`, and a `biome.json` unless a folder above already has one.

What the `tsconfig.json` options are for:

| Option | Why |
|---|---|
| `strict`, `noUncheckedIndexedAccess` | the most hints; `arr[0]` is treated as possibly `undefined` |
| `types: ["node"]` | TypeScript 7 no longer loads Node types on its own |
| `moduleDetection: "force"` | each file is its own module, so `const x` in two files does not clash |
| `allowJs`, `checkJs` | plain `.js` files are checked too |
| `noEmit` | `tsc` only checks; Node runs the files |

**Check:** `node index.ts` prints `hello from my-app`, and `tsc --noEmit` and `biome check .` report no problems.

---

## 11. Daily use

| I want to | Do this |
|---|---|
| Run the open file | click ▶ or press Ctrl+Alt+N |
| Re-run on every save | `nw index.ts` |
| Format and auto-fix | Ctrl+S, or `biome check --write .` |
| Check types across the project | `tsc --noEmit` |
| See the type of something | put `//  ^?` on the next line, with `^` under the name |
| Jump to a project folder | `z my-app` |
| Remember how a command works | `tldr <command>` |

Node strips the types and runs the file. It does not check them. The red squiggles in the editor and `tsc --noEmit` do the checking.

## 12. The debugger (use it early)

1. Ctrl+Shift+P, run **Debug: JavaScript Debug Terminal**.
2. Click left of a line number to set a red dot.
3. Run `node index.ts` in that terminal. It pauses on the dot and shows every variable.

## 13. Ten shortcuts

| Keys | Action |
|---|---|
| Ctrl+P | open a file by name |
| Ctrl+Shift+P | run any command |
| Ctrl+` | show or hide the terminal |
| Ctrl+B | show or hide the file list |
| Ctrl+. | quick fix for the error under the cursor |
| F2 | rename a variable everywhere |
| F12 | go to definition |
| Alt+Up / Alt+Down | move the line |
| Ctrl+D | select the next match (multi-cursor) |
| Ctrl+/ | comment the line |

## 14. When something is off

| Symptom | Fix |
|---|---|
| A paste shows `[200~` and the command fails | press Ctrl+C, then paste again; if it keeps happening, add `set enable-bracketed-paste off` to `~/.inputrc` and open a new terminal |
| The prompt is stuck on `>` | bash is waiting for the rest of a command; press Ctrl+C |
| Terminal will not open | in `settings.json`, replace `${env:USERPROFILE}` with your real path, such as `C:\\Users\\You` |
| `bash: $'\r': command not found` | the file has CRLF endings; click **CRLF** in the status bar, pick **LF**, save |
| Rocket shows as a box | the terminal font is not JetBrains Mono; recheck step 2 and the font settings |
| Save does not format | run `biomehere` in the folder; then check **Output → Biome** |
| `Found a nested root configuration` | two `biome.json` files are stacked; delete the inner one |
| Biome extension cannot find Biome | set `"biome.lsp.bin"` to `C:\\Users\\You\\scoop\\persist\\nodejs\\bin\\node_modules\\@biomejs\\biome\\node_modules\\@biomejs\\cli-win32-x64\\biome.exe` |
| `TS1287` on `export` | `package.json` is missing `"type": "module"` |
| `Cannot find name 'process'` | run `npm i -D @types/node`; check `"types": ["node"]` |
| `ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX` | the file uses `enum` or similar; run it with `tsx file.ts` |
| Biome reports an unknown rule after an update | run `biome migrate --write` |

## 15. What was tested

Tested on Windows 11 with the versions listed at the top:

- Every Scoop package name exists in its bucket, and every extension ID exists on the marketplace.
- Most VS Code setting keys were confirmed against VS Code 1.140 or the extension that owns them. The `telemetry.*`, `chat.*` and most `code-runner.*` keys were not checked individually.
- The `.bashrc` and `.inputrc` content runs in Git Bash 5.3 without errors: prompt colors, git branch, aliases, and loading it twice.
- `newproj` produces a project where `node index.ts` runs, `tsc --noEmit` passes and catches a type error, and `biome check .` is clean, also after installing a package.
- The Biome config is valid for 2.5.15 and its rules fire, including the forgotten-`await` rule.
- `biomehere` writes a config in a bare folder, reuses one from a folder above, and leaves an existing one alone. Biome runs cleanly from both the project and the folder above it.

Not tested:

- The Scoop install itself, and the `zoxide`, `fzf`, `eza`, `bat` and `tldr` lines in `.bashrc`.
- `${env:USERPROFILE}` in the terminal profile path. A full path is known to work.
- The Biome extension picking up the global install. Its code looks in global `node_modules` and on `PATH`, but this was not observed running.
- How the Replit navy colors look on screen.
- Twoslash and Pretty TypeScript Errors against TypeScript 7 in the editor.

## 16. If some of this is already installed

- **Tools:** Scoop skips anything it already installed, and reinstalling an extension or a global npm package is harmless.
- **An existing `~/.bash_profile` or `~/.bashrc`:** keep your own lines and add the blocks from step 7. The prompt block is safe to load more than once.
- **An existing `settings.json`:** merge key by key, and keep only one copy of each key.
- **A folder that already has a `biome.json`:** `newproj` and `biomehere` reuse it and write nothing.
