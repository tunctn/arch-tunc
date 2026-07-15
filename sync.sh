#!/usr/bin/env bash
# Collect Arch setup (package manifests + allowlisted dotfiles + allowlisted
# system files) into this repo and push to GitHub, but only commit when
# something actually changed.
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

# --- 2b. allowlisted system files (absolute paths, outside $HOME) ---------
# Regenerated from scratch each run so entries removed from system.list also
# disappear here. Runs as the normal user: root-owned files are copied only if
# they are world-readable, never via sudo.
rm -rf system
mkdir -p system
while IFS= read -r raw; do
    line="${raw%%#*}"                       # strip inline comments
    line="$(printf '%s' "$line" | xargs || true)"   # trim whitespace
    [ -z "$line" ] && continue
    case "$line" in /*) ;; *) continue ;; esac      # absolute paths only
    dest="system/${line#/}"
    [ -e "$line" ] && [ -r "$line" ] || continue    # skip missing/unreadable
    mkdir -p "$(dirname "$dest")"
    cp -a "$line" "$dest"
done < system.list

# Which gh-runner@ template instances are enabled (i.e. how many parallel
# slots, for which repo) — needed to reproduce the setup on restore.
find /etc/systemd/system/multi-user.target.wants -maxdepth 1 \
    -name 'gh-runner@*.service' -printf '%f\n' 2>/dev/null \
    | sort > system/enabled-gh-runners.txt || true

# --- 3. commit + push only if there is a diff ----------------------------
git add -A
if git diff --cached --quiet; then
    exit 0                                   # nothing changed, stay quiet
fi
git commit -q -m "sync: $(date -Iseconds) on $(uname -n)"
git push -q
