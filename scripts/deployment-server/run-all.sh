#!/usr/bin/env bash
# Orchestrator — runs steps 00..05 then verification in order. Each step is
# idempotent, so re-running this is safe.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

for step in \
  00-check-prereqs.sh \
  01-enable-receiving.sh \
  02-enable-deployment-server.sh \
  03-install-deployment-apps.sh \
  04-configure-serverclasses.sh \
  05-reload-deployment-server.sh \
  99-verify.sh
do
  echo
  echo "────────────────────────────────────────────────────────────────────"
  echo "Running ${step}"
  echo "────────────────────────────────────────────────────────────────────"
  "${HERE}/${step}"
done
