#!/usr/bin/env bash
# Step 0 — sanity-check that the lab stack is ready to be configured as a
# deployment server + receiver.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Step 0 — preflight checks"

bootstrap

info "Verifying Splunk management port on :8089 responds…"
if splunk_cli status | grep -q "splunkd is running"; then
  success "splunkd is running inside the '${SPLUNK_SERVICE}' container"
else
  err "splunkd is not running — check 'docker compose logs splunk'"
  exit 1
fi

info "Splunk version:"
splunk_cli version || true

success "Preflight complete — proceed to step 01."
