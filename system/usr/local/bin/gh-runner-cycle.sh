#!/bin/bash
# One ephemeral GitHub Actions runner cycle for wusthq/<repo> inside the "ci" incus container.
# Instance format: "<repo>" (slot 1) or "<repo>:N" for extra parallel slots,
# e.g. gh-runner@homemade-dev:2. Runs on the HOST as root; the PAT never enters
# the container. Driven by gh-runner@.service.
set -euo pipefail
INSTANCE="$1"
REPO="${INSTANCE%%:*}"
SLOT="${INSTANCE#*:}"; [ "$SLOT" = "$INSTANCE" ] && SLOT=1
SUFFIX=""; [ "$SLOT" != "1" ] && SUFFIX="-$SLOT"

source /root/gh-runner.env

REG_TOKEN=$(curl -sf -X POST \
  -H "Authorization: Bearer ${GH_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/wusthq/${REPO}/actions/runners/registration-token" | jq -r .token)

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
  echo "failed to obtain registration token for wusthq/${REPO}" >&2
  exit 1
fi

exec incus exec ci --env REPO="$REPO" --env SUFFIX="$SUFFIX" --env REG_TOKEN="$REG_TOKEN" -- bash -euo pipefail -c '
  DIR=/opt/actions-runner/repo-$REPO$SUFFIX
  if [ ! -x "$DIR/run.sh" ]; then
    mkdir -p "$DIR"
    cp -a /opt/actions-runner/dist/. "$DIR/"
  fi
  # clean slate every cycle: no leftover work dir or credentials
  rm -rf "$DIR/_work" "$DIR/.runner" "$DIR/.credentials" "$DIR/.credentials_rsaparams" "$DIR/.docker"
  chown -R gh-runner:gh-runner "$DIR"
  runuser -u gh-runner -- bash -c "cd $DIR && ./config.sh --url https://github.com/wusthq/$REPO --token $REG_TOKEN --name ci-$REPO$SUFFIX --labels self-hosted,home,tunc-arch --ephemeral --unattended --replace"
  # per-slot docker credentials: parallel jobs share one dockerd, and
  # docker/login-action logs out in its post step — without this a finishing
  # job wipes the creds a concurrent push is using
  echo "DOCKER_CONFIG=$DIR/.docker" >> "$DIR/.env"
  chown gh-runner:gh-runner "$DIR/.env"
  exec runuser -u gh-runner -- bash -c "cd $DIR && ./run.sh"
'
