#!/bin/bash

# 1. GitHub Account Details
S1_EMAIL="135691331+swapnanil1@users.noreply.github.com"
S2_EMAIL="263302256+swapnanil2@users.noreply.github.com"
S1_NAME="swapnanil1"
S2_NAME="swapnanil2"

# 2. Create your repository directories
mkdir -p ~/repos/swapnanil1
mkdir -p ~/repos/swapnanil2
mkdir -p ~/.ssh

# 3. Generate SSH keys (creates id_s1 and id_s2 with no passphrases)
if [ ! -f ~/.ssh/id_s1 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_s1 -C "$S1_EMAIL" -N ""
fi
if [ ! -f ~/.ssh/id_s2 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_s2 -C "$S2_EMAIL" -N ""
fi

# 4. Append the short aliases to your SSH config
cat << 'EOF' >> ~/.ssh/config

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
EOF

# 5. Create the folder-specific Git config files
cat << EOF > ~/.gitconfig-s1
[user]
    name = $S1_NAME
    email = $S1_EMAIL
EOF

cat << EOF > ~/.gitconfig-s2
[user]
    name = $S2_NAME
    email = $S2_EMAIL
EOF

# 6. Clear global identity (forces the failsafe) and link the folder configs
git config --global --unset-all user.name 2>/dev/null || true
git config --global --unset-all user.email 2>/dev/null || true

git config --global includeIf."gitdir:~/repos/swapnanil1/".path "~/.gitconfig-s1"
git config --global includeIf."gitdir:~/repos/swapnanil2/".path "~/.gitconfig-s2"

# 7. Final Instructions and Explanations printed to the terminal
echo -e "\n========================================================"
echo " STEP 1: ADD KEYS TO GITHUB"
echo "========================================================"
echo "Copy this key to your FIRST account (swapnanil1):"
cat ~/.ssh/id_s1.pub
echo -e "\nCopy this key to your SECOND account (swapnanil2):"
cat ~/.ssh/id_s2.pub

echo -e "\n========================================================"
echo " STEP 2: TEST YOUR CONNECTION"
echo "========================================================"
echo "Once you have added the keys to GitHub, run these tests:"
echo "  ssh -T s1"
echo "  ssh -T s2"
echo "If successful, GitHub will reply with 'Hi username! You've successfully authenticated...'"

echo -e "\n========================================================"
echo " STEP 3: HOW TO CLONE REPOSITORIES"
echo "========================================================"
echo "When cloning, you MUST replace 'git@github.com:' with your alias ('s1:' or 's2:')."
echo ""
echo "❌ WRONG: git clone git@github.com:swapnanil1/repo.git"
echo "✅ RIGHT: git clone s1:swapnanil1/repo.git"

echo -e "\n========================================================"
echo " STEP 4: INITIALIZING OR FIXING EXISTING REPOSITORIES"
echo "========================================================"
echo "If you run 'git init' locally, or if you already have a cloned"
echo "repository that is failing to push, use these commands:"
echo ""
echo "To ADD a remote to a newly initialized repository:"
echo "👉 git remote add origin s1:swapnanil1/repo.git"
echo ""
echo "To FIX an existing repository URL (replace the bad link):"
echo "👉 git remote set-url origin s1:swapnanil1/repo.git"
echo "========================================================"
echo "Setup Complete!"
