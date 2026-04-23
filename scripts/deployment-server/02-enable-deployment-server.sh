#!/usr/bin/env bash
# Step 2 — mark this instance as a Deployment Server. In Splunk, an instance
# becomes a deployment server as soon as at least one serverClass stanza is
# present in serverclass.conf under system/local and 'splunk reload
# deploy-server' has been run. This step seeds an empty serverclass.conf with a
# [global] stanza so later steps can layer server classes on top cleanly.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Step 2 — promote to deployment server"

bootstrap

SERVERCLASS_CONF="${SYSTEM_LOCAL_PATH}/serverclass.conf"

info "Ensuring ${SERVERCLASS_CONF} exists with a [global] stanza…"
splunk_sh "cat > '${SERVERCLASS_CONF}.tmp' <<'EOF'
# Managed by scripts/deployment-server/02-enable-deployment-server.sh.
# Server class stanzas are layered on by step 04.

[global]
restartSplunkWeb = false
restartSplunkd = false
stateOnClient = enabled
EOF
# Preserve any existing serverClass stanzas the user added manually.
if [[ -f '${SERVERCLASS_CONF}' ]]; then
  awk '/^\[serverClass:/{p=1} p' '${SERVERCLASS_CONF}' >> '${SERVERCLASS_CONF}.tmp' || true
fi
mv '${SERVERCLASS_CONF}.tmp' '${SERVERCLASS_CONF}'"

success "Wrote ${SERVERCLASS_CONF}"

info "Reloading deployment server so splunkd picks up the new config…"
if splunk_cli reload deploy-server 2>&1 | tee /dev/stderr | grep -q "Reloading"; then
  success "Deployment server reloaded"
else
  # 'reload deploy-server' is a no-op on fresh installs with no classes yet;
  # the command still returns 0, so don't fail here.
  warn "Reload returned no classes yet — that's fine, step 04 will add them."
fi
