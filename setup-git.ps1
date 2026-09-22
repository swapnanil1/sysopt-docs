# Windows port of setup-git.sh: two GitHub accounts, SSH aliases s1/s2, per-folder git identity.
# Run in PowerShell (5.1 or 7+). No admin needed. Requires Git for Windows (winget install Git.Git).

# 1. GitHub Account Details
$S1_EMAIL = "135691331+swapnanil1@users.noreply.github.com"
$S2_EMAIL = "263302256+swapnanil2@users.noreply.github.com"
$S1_NAME  = "swapnanil1"
$S2_NAME  = "swapnanil2"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "git not found. Install it, reopen PowerShell, then rerun this script:"
    Write-Host "  winget install --id Git.Git -e"
    exit 1
}
if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    Write-Host "ssh-keygen not found. Enable it with: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
    exit 1
}

# Git and OpenSSH on Windows both treat %USERPROFILE% as ~
$UserHome = $env:USERPROFILE
$SshDir   = Join-Path $UserHome ".ssh"
$HomeFwd  = $UserHome -replace '\\', '/'   # git wants forward slashes in gitdir: patterns

# UTF-8 without BOM: PowerShell 5.1's default Out-File encoding (UTF-16) is unreadable to ssh/git
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 2. Create your repository directories
$null = New-Item -ItemType Directory -Force -Path (Join-Path $UserHome "repos\swapnanil1")
$null = New-Item -ItemType Directory -Force -Path (Join-Path $UserHome "repos\swapnanil2")
$null = New-Item -ItemType Directory -Force -Path $SshDir

# 3. Generate SSH keys (creates id_s1 and id_s2 with no passphrases)
# --% stops PowerShell parsing so the empty -N "" is passed through intact; %VAR% still expands.
$env:GIT_SETUP_KEY   = Join-Path $SshDir "id_s1"
$env:GIT_SETUP_EMAIL = $S1_EMAIL
if (-not (Test-Path $env:GIT_SETUP_KEY)) {
    ssh-keygen --% -t ed25519 -f "%GIT_SETUP_KEY%" -C "%GIT_SETUP_EMAIL%" -N ""
}
$env:GIT_SETUP_KEY   = Join-Path $SshDir "id_s2"
$env:GIT_SETUP_EMAIL = $S2_EMAIL
if (-not (Test-Path $env:GIT_SETUP_KEY)) {
    ssh-keygen --% -t ed25519 -f "%GIT_SETUP_KEY%" -C "%GIT_SETUP_EMAIL%" -N ""
}
Remove-Item Env:\GIT_SETUP_KEY, Env:\GIT_SETUP_EMAIL

# 4. Append the short aliases to your SSH config (skipped if already present)
$SshConfig = Join-Path $SshDir "config"
$SshBlock = @"

# Account 1: swapnanil1
Host s1
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_s1
    IdentitiesOnly yes

# Account 2: swapnanil2
Host s2
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_s2
    IdentitiesOnly yes
"@
if (-not (Test-Path $SshConfig) -or -not (Select-String -Path $SshConfig -Pattern '^\s*Host\s+s1\s*$' -Quiet)) {
    [System.IO.File]::AppendAllText($SshConfig, $SshBlock, $Utf8NoBom)
}

# 5. Create the folder-specific Git config files
[System.IO.File]::WriteAllText((Join-Path $UserHome ".gitconfig-s1"), @"
[user]
    name = $S1_NAME
    email = $S1_EMAIL
"@, $Utf8NoBom)

[System.IO.File]::WriteAllText((Join-Path $UserHome ".gitconfig-s2"), @"
[user]
    name = $S2_NAME
    email = $S2_EMAIL
"@, $Utf8NoBom)

# 6. Clear global identity (forces the failsafe) and link the folder configs
git config --global --unset-all user.name  2>$null
git config --global --unset-all user.email 2>$null

git config --global "includeIf.gitdir:$HomeFwd/repos/swapnanil1/.path" "$HomeFwd/.gitconfig-s1"
git config --global "includeIf.gitdir:$HomeFwd/repos/swapnanil2/.path" "$HomeFwd/.gitconfig-s2"

# 7. Final Instructions and Explanations printed to the terminal
Write-Host "`n========================================================"
Write-Host " STEP 1: ADD KEYS TO GITHUB"
Write-Host "========================================================"
Write-Host "Copy this key to your FIRST account (swapnanil1):"
Get-Content (Join-Path $SshDir "id_s1.pub")
Write-Host "`nCopy this key to your SECOND account (swapnanil2):"
Get-Content (Join-Path $SshDir "id_s2.pub")

Write-Host "`n========================================================"
Write-Host " STEP 2: TEST YOUR CONNECTION"
Write-Host "========================================================"
Write-Host "Once you have added the keys to GitHub, run these tests:"
Write-Host "  ssh -T s1"
Write-Host "  ssh -T s2"
Write-Host "If successful, GitHub will reply with 'Hi username! You've successfully authenticated...'"

Write-Host "`n========================================================"
Write-Host " STEP 3: HOW TO CLONE REPOSITORIES"
Write-Host "========================================================"
Write-Host "When cloning, you MUST replace 'git@github.com:' with your alias ('s1:' or 's2:')."
Write-Host ""
Write-Host "WRONG: git clone git@github.com:swapnanil1/repo.git"
Write-Host "RIGHT: git clone s1:swapnanil1/repo.git"

Write-Host "`n========================================================"
Write-Host " STEP 4: INITIALIZING OR FIXING EXISTING REPOSITORIES"
Write-Host "========================================================"
Write-Host "If you run 'git init' locally, or if you already have a cloned"
Write-Host "repository that is failing to push, use these commands:"
Write-Host ""
Write-Host "To ADD a remote to a newly initialized repository:"
Write-Host "  git remote add origin s1:swapnanil1/repo.git"
Write-Host ""
Write-Host "To FIX an existing repository URL (replace the bad link):"
Write-Host "  git remote set-url origin s1:swapnanil1/repo.git"
Write-Host "========================================================"
Write-Host "Setup Complete!"
