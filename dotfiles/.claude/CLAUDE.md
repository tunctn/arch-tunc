# Machine setup is backed up to the `arch-tunc` repo

This Arch Linux machine's setup is continuously backed up to `~/arch-tunc`
(GitHub: `tunctn/arch-tunc`). A systemd user timer runs `~/arch-tunc/sync.sh`
every minute and pushes **only when something changed**.

## How it works
- **Packages** — explicitly installed pacman + AUR packages are captured
  **automatically** into `packages/*.txt`. Installing something = no action needed.
- **Files** — ONLY paths listed in `~/arch-tunc/dotfiles.list` (an allowlist,
  relative to `$HOME`) are copied into the repo and pushed. Anything not listed
  is NOT backed up.

## What you (Claude) should do
When you install an app, create a new config, or generate data/files that would
be **worth keeping across machines** (e.g. a new `~/.config/<app>`, an important
dotfile, a data/assets folder):

1. Check whether the relevant path is already covered in `~/arch-tunc/dotfiles.list`.
2. If not, and it's clearly config/data the user would want persisted → **add the
   path to `~/arch-tunc/dotfiles.list`**, then mention that you did.
3. If it's ambiguous, large/binary, or possibly personal → **ASK the user first**
   whether to add it to the arch-tunc backup.
4. After editing the allowlist you may run `~/arch-tunc/sync.sh` to push
   immediately; otherwise the timer picks it up within ~60s.

## NEVER add secrets to the allowlist
Never add paths containing credentials or private data, e.g. `.ssh`,
`.claude/.credentials.json`, `.config/1Password`, `.config/op`, browser profiles
(`.config/google-chrome*`, `.config/BraveSoftware`, `.config/vivaldi*`,
`.mozilla`), `.env` files, API tokens, or keyrings. When unsure, ask.

The repo is (and must stay) **private**.
