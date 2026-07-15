# Self-hosted GitHub Actions runners (`tunc-arch`)

This machine runs ephemeral self-hosted Actions runners for **`wusthq/homemade-dev`**.
Everything reproducible is tracked in this repo; the two things that are *not*
(a PAT and a container rootfs) are described under [Manual restore steps](#manual-restore-steps).

## How it works

```
systemd (host, root)
  gh-runner@homemade-dev.service     -> slot 1   ci-homemade-dev
  gh-runner@homemade-dev:2.service   -> slot 2   ci-homemade-dev-2
  gh-runner@homemade-dev:3.service   -> slot 3   ci-homemade-dev-3
        |
        | ExecStart=/usr/local/bin/gh-runner-cycle.sh %i
        v
  gh-runner-cycle.sh  (HOST, root)
        1. source /root/gh-runner.env            -> GH_PAT
        2. POST /repos/wusthq/<repo>/actions/runners/registration-token
                                                 -> short-lived REG_TOKEN
        3. incus exec ci -- ... (passes only REG_TOKEN, never the PAT)
        |
        v
  incus container "ci"  (unprivileged user: gh-runner)
        /opt/actions-runner/dist          <- pristine runner tarball (v2.335.1)
        /opt/actions-runner/repo-<repo>[-N]  <- per-slot working copy
        config.sh --ephemeral --unattended --replace
        run.sh   -> picks up exactly ONE job, then exits
        |
        v
  runner exits -> systemd Restart=always (RestartSec=15) -> fresh cycle
```

### Why it's built this way

- **The PAT never enters the container.** The host mints a short-lived
  registration token and passes only that in. A compromised CI job can't read
  the long-lived credential.
- **`--ephemeral` = one job per runner.** GitHub retires the registration after
  a single job; `Restart=always` then starts a clean cycle. No state leaks
  between jobs.
- **Clean slate every cycle.** `_work`, `.runner`, `.credentials`,
  `.credentials_rsaparams`, and `.docker` are deleted before each `config.sh`.
- **Per-slot docker credentials.** All slots share one dockerd, and
  `docker/login-action` logs out in its post step — so a finishing job would wipe
  the registry creds a *concurrent* job is still pushing with (symptom: `error
  from registry: unauthorized` on a push that should work). The cycle script
  writes `DOCKER_CONFIG=$DIR/.docker` into each slot's `.env`, giving every slot
  isolated credentials. This is a direct consequence of running >1 slot; do not
  remove it while parallel slots are enabled.
- **Container isolation.** Jobs run as unprivileged `gh-runner` inside incus,
  not on the host. `Requires=incus.service` so the units can't start without it.
- **`ExecStopPost`** pkills the in-container `Runner.Listener` so a stopped unit
  doesn't leave an orphan listener holding a registration.

### Labels

`self-hosted,home,tunc-arch` — target from a workflow with:

```yaml
runs-on: [self-hosted, tunc-arch]
```

## What this repo tracks

| Path | Purpose |
|---|---|
| `system/etc/systemd/system/gh-runner@.service` | the template unit |
| `system/usr/local/bin/gh-runner-cycle.sh` | the per-cycle driver |
| `system/enabled-gh-runners.txt` | which slots are enabled (= parallelism) |
| `system.list` | allowlist that drives the two above into the repo |

`incus` itself is captured in `packages/pacman-explicit.txt`.

## NOT tracked, by design

- **`/root/gh-runner.env`** — holds `GH_PAT`. A secret; never add it to
  `system.list`. Also unreadable by the sync (which runs as `tunc`, not root).
- **The `ci` container** — a multi-GB rootfs, not a config file. Recreate it.

## Manual restore steps

`restore.sh` puts the unit + script back and reloads systemd, but the runners
will not start until you do the following.

### 1. Recreate the PAT file

```bash
sudo install -m 600 /dev/null /root/gh-runner.env
sudo tee /root/gh-runner.env >/dev/null <<'EOF'
GH_PAT=github_pat_xxxxxxxxxxxxxxxxxxxx
EOF
```

The PAT needs **Administration: read & write** on `wusthq/homemade-dev` (that
scope is what allows minting runner registration tokens). Use a fine-grained,
repo-scoped token — not a classic org-wide one.

### 2. Recreate the `ci` container

```bash
incus launch images:archlinux/current ci      # any modern distro works
incus exec ci -- useradd -m -s /bin/bash gh-runner
incus exec ci -- mkdir -p /opt/actions-runner/dist
# download the runner tarball into /opt/actions-runner/dist and extract it:
incus exec ci -- bash -c '
  cd /opt/actions-runner/dist &&
  curl -sfLo r.tar.gz https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz &&
  tar xzf r.tar.gz && rm r.tar.gz &&
  ./bin/installdependencies.sh &&
  chown -R gh-runner:gh-runner /opt/actions-runner'
```

`cycle.sh` copies `dist/` into a per-slot `repo-<repo>[-N]` dir on first run, so
`dist` must stay pristine. Whatever your jobs need (docker/podman, node, etc.)
must also be installed *in the container*, not on the host.

### 3. Enable the slots

```bash
# one unit per parallel job; see system/enabled-gh-runners.txt
sudo systemctl enable --now gh-runner@homemade-dev.service
sudo systemctl enable --now 'gh-runner@homemade-dev:2.service'
sudo systemctl enable --now 'gh-runner@homemade-dev:3.service'
```

## Operating notes

```bash
systemctl status 'gh-runner@*'                    # all slots
journalctl -u 'gh-runner@homemade-dev:2' -f       # follow one slot
sudo systemctl restart 'gh-runner@homemade-dev:3' # force a fresh cycle
```

- **Add a slot:** `sudo systemctl enable --now 'gh-runner@homemade-dev:4.service'`.
  The instance name is `<repo>` for slot 1, `<repo>:N` after that. Nothing else
  to edit — `cycle.sh` derives dir/name from `%i`.
- **Add a second repo:** `sudo systemctl enable --now gh-runner@<other-repo>.service`.
  The repo must live under the `wusthq` org (hardcoded in `cycle.sh`) and the
  PAT must cover it.
- **Rotating the PAT** only touches `/root/gh-runner.env`; running slots pick it
  up on their next cycle.
- **`Restart=always` means a misconfigured slot retries every 15s forever** — if
  a slot flaps, check the journal rather than waiting it out.
