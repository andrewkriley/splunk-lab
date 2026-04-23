#!/usr/bin/env bash
# Step 5 — make the deployment server re-read serverclass.conf and repackage
# the deployment apps so phoning-home forwarders pick up the new bundle.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Step 5 — reload deployment server"

bootstrap

info "splunk reload deploy-server"
splunk_cli reload deploy-server

success "Deployment server reloaded. Forwarders will receive updates on their next poll (default 60s)."
