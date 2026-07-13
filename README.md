# arch-tunc

Automatic, periodic backup of my Arch Linux setup.

A systemd user timer runs [`sync.sh`](./sync.sh) every minute; it commits and
pushes **only when something changed**. Secrets are kept out by an **allowlist**
([`dotfiles.list`](./dotfiles.list)) — only listed paths are ever copied here.

## What's tracked
- `packages/pacman-explicit.txt` — native explicit installs (`pacman -Qqen`)
- `packages/aur-explicit.txt` — AUR/foreign explicit installs (`pacman -Qqem`)
- `dotfiles/` — copies of the paths in `dotfiles.list`

## Restore on a fresh machine
```bash
git clone git@github-arch-tunc:tunctn/arch-tunc.git ~/arch-tunc
cd ~/arch-tunc && ./restore.sh
```

## Add more dotfiles
Edit `dotfiles.list`. Never add anything with secrets (`.ssh`, browser
profiles, `.config/1Password`, `.config/op`, `.env`, etc.).

## Timer
```bash
systemctl --user status  arch-sync.timer   # check
systemctl --user disable --now arch-sync.timer   # stop
journalctl --user -u arch-sync.service -n 20     # recent runs
```
