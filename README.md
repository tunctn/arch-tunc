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

### Manual steps after `restore.sh`
Some state is identity/secret material and is deliberately **not** in this repo.
Packages and configs come back on their own; these do not:

**Tailscale** — node keys live in `/var/lib/tailscale/` (root-owned, outside
`$HOME`, so the allowlist can't reach them). Re-auth instead:
```bash
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh          # --ssh: this machine's current setting
```

**Sunshine** — web-UI login and paired-client certs are not portable:
```bash
systemctl --user enable --now app-dev.lizardbyte.app.Sunshine.service
# then open https://<tailscale-ip>:47990 to set the login and re-pair clients
```
`sunshine.conf` pins `csrf_allowed_origins` to this machine's Tailscale IP
(`100.121.117.119`) — update it if the tailnet IP changes.

## Add more dotfiles
Edit `dotfiles.list`. Never add anything with secrets (`.ssh`, browser
profiles, `.config/1Password`, `.config/op`, `.env`, etc.).

Prefer listing **individual files** over a whole directory when an app mixes
config with secrets — `.config/sunshine` is the worked example.

## Timer
```bash
systemctl --user status  arch-sync.timer   # check
systemctl --user disable --now arch-sync.timer   # stop
journalctl --user -u arch-sync.service -n 20     # recent runs
```
