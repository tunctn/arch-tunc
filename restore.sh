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
