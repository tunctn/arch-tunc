#!/usr/bin/env bash
# Rebuild a machine from this repo: install packages, then restore dotfiles.
# Run on a fresh Arch install after cloning this repo.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo ">> Installing native (pacman) packages..."
if [ -s packages/pacman-explicit.txt ]; then
    sudo pacman -S --needed - < packages/pacman-explicit.txt
fi

echo ">> Installing AUR packages..."
if [ -s packages/aur-explicit.txt ]; then
    if command -v yay >/dev/null; then
        yay -S --needed - < packages/aur-explicit.txt
    else
        echo "!! yay not found — install an AUR helper first, then re-run." >&2
    fi
fi

echo
echo ">> This will copy tracked dotfiles into $HOME, OVERWRITING existing files:"
( cd dotfiles && find . -mindepth 1 -maxdepth 2 | sed 's|^\./|  ~/|' )
read -r -p ">> Continue? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    cp -a dotfiles/. "$HOME/"
    echo ">> Dotfiles restored."
else
    echo ">> Skipped dotfiles."
fi

# --- system files (root-owned, outside $HOME) ----------------------------
if [ -d system ] && [ -n "$(find system -type f -not -name 'enabled-gh-runners.txt' -print -quit)" ]; then
    echo
    echo ">> This will copy tracked system files as ROOT, OVERWRITING existing files:"
    ( cd system && find . -type f -not -name 'enabled-gh-runners.txt' | sed 's|^\./|  /|' )
    read -r -p ">> Continue? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        while IFS= read -r f; do
            rel="${f#system/}"
            sudo install -D -m "$(stat -c %a "$f")" -o root -g root "$f" "/$rel"
        done < <(find system -type f -not -name 'enabled-gh-runners.txt')
        sudo systemctl daemon-reload
        echo ">> System files restored."
        echo
        echo "!! The GitHub Actions runner needs manual steps before it will start."
        echo "!! See docs/gh-runner.md — in short:"
        echo "!!   1. create /root/gh-runner.env with GH_PAT=<repo-scoped PAT>  (NOT in this repo)"
        echo "!!   2. create the 'ci' incus container + gh-runner user + /opt/actions-runner/dist"
        echo "!!   3. enable the slots listed in system/enabled-gh-runners.txt"
    else
        echo ">> Skipped system files."
    fi
fi
