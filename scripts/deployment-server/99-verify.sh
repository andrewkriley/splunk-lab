#!/usr/bin/env bash
# Step 99 — read-only verification that the receiver is listening, the
# deployment apps are installed, and the server classes resolve.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Verification"

bootstrap

info "Receiving port (expect :${SPLUNK_RECEIVING_PORT}):"
splunk_cli display listen-ports 2>/dev/null || warn "display listen-ports not available"

info "Deployment apps on disk:"
splunk_sh "ls -1 '${DEPLOY_APPS_PATH}'"

info "Server classes defined:"
splunk_sh "grep -E '^\[serverClass:' '${SYSTEM_LOCAL_PATH}/serverclass.conf' || echo '  (none — run step 04)'"

info "Deployment server REST view (serverclasses endpoint):"
splunk_cli list deploy-server-class 2>/dev/null || warn "list deploy-server-class not supported — use Splunk Web → Settings → Forwarder management"

success "Verification complete."
info "Point forwarders at this deployment server by installing"
info "  ${APPS_DIR}/forwarder-client-template/local/deploymentclient.conf"
info "on each forwarder and setting clientName to uf-* or hf-* to pick the class."
