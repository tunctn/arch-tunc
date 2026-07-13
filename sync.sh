#!/usr/bin/env bash
# Collect Arch setup (package manifests + allowlisted dotfiles) into this repo
# and push to GitHub, but only commit when something actually changed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# --- 1. package manifests -------------------------------------------------
mkdir -p packages
pacman -Qqen | sort > packages/pacman-explicit.txt   # native, explicitly installed
pacman -Qqem | sort > packages/aur-explicit.txt      # foreign/AUR, explicitly installed

# --- 2. allowlisted dotfiles ---------------------------------------------
mkdir -p dotfiles
while IFS= read -r raw; do
    line="${raw%%#*}"                       # strip inline comments
    line="$(printf '%s' "$line" | xargs || true)"   # trim whitespace
    [ -z "$line" ] && continue
    src="$HOME/$line"
    dest="dotfiles/$line"
    [ -e "$src" ] || continue               # skip paths that don't exist
    rm -rf "$dest"                           # reflect deletions inside dirs
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
done < dotfiles.list

# --- 3. commit + push only if there is a diff ----------------------------
git add -A
if git diff --cached --quiet; then
    exit 0                                   # nothing changed, stay quiet
fi
git commit -q -m "sync: $(date -Iseconds) on $(uname -n)"
git push -q
