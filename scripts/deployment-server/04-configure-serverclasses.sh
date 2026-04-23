#!/usr/bin/env bash
# Step 4 — map deployment apps to server classes. Three classes are defined:
#
#   all_forwarders        → every client (both UF and HF). Pushes outputs.conf.
#   universal_forwarders  → matches clientName 'uf-*'. Pushes UF input template.
#   heavy_forwarders      → matches clientName 'hf-*'. Pushes HF inputs and the
#                           parsing/routing app (props + transforms).
#
# Matching is by clientName (set in deploymentclient.conf on the forwarder).
# The UF/HF split works because HFs need parsing-time configs that UFs ignore,
# and pushing them to UFs just wastes deploy cycles.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Step 4 — define server classes and attach apps"

bootstrap

SERVERCLASS_CONF="${SYSTEM_LOCAL_PATH}/serverclass.conf"

info "Writing ${SERVERCLASS_CONF}…"
splunk_sh "cat > '${SERVERCLASS_CONF}' <<'EOF'
# Managed by scripts/deployment-server/04-configure-serverclasses.sh.
# Edit via the step script so regenerations stay idempotent.

[global]
restartSplunkWeb = false
restartSplunkd = false
stateOnClient = enabled

# ── all_forwarders ──────────────────────────────────────────────────────────
# Every forwarder gets the outputs app so it knows where to ship events.
[serverClass:all_forwarders]
whitelist.0 = *

[serverClass:all_forwarders:app:all_forwarders_outputs]
restartSplunkd = true
stateOnClient = enabled

# ── universal_forwarders ────────────────────────────────────────────────────
# Matches deploymentclient.conf clientName = uf-*
[serverClass:universal_forwarders]
whitelist.0 = uf-*

[serverClass:universal_forwarders:app:uf_base_inputs]
restartSplunkd = true
stateOnClient = enabled

# ── heavy_forwarders ────────────────────────────────────────────────────────
# Matches deploymentclient.conf clientName = hf-*
[serverClass:heavy_forwarders]
whitelist.0 = hf-*

[serverClass:heavy_forwarders:app:hf_base_inputs]
restartSplunkd = true
stateOnClient = enabled

[serverClass:heavy_forwarders:app:hf_indexing_routes]
restartSplunkd = true
stateOnClient = enabled
EOF"

success "serverclass.conf written with 3 classes / 4 app bindings"

info "Rendered server classes:"
splunk_sh "grep -E '^\[serverClass:' '${SERVERCLASS_CONF}'"
