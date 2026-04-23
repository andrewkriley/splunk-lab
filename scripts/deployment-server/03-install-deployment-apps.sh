#!/usr/bin/env bash
# Step 3 — copy the deployment apps from scripts/deployment-server/apps/ into
# ${SPLUNK_HOME}/etc/deployment-apps inside the Splunk container. These are the
# apps the deployment server will push to forwarders when they phone home.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Step 3 — install deployment apps"

bootstrap

# Apps that represent real deployment-app payloads (the forwarder-client
# template is a host-side reference file, not pushed by the DS).
APPS=(
  all_forwarders_outputs
  uf_base_inputs
  hf_base_inputs
  hf_indexing_routes
)

for app in "${APPS[@]}"; do
  src="${APPS_DIR}/${app}"
  if [[ ! -d "$src" ]]; then
    err "Source app missing: ${src}"
    exit 1
  fi
  dest="${DEPLOY_APPS_PATH}/${app}"
  info "Installing ${app} → ${dest}"
  # Clean any previous copy so renamed/removed files don't linger.
  splunk_sh "rm -rf '${dest}' && mkdir -p '${DEPLOY_APPS_PATH}'"
  copy_into_container "$src" "$dest"
  success "Installed ${app}"
done

info "Deployment apps now present inside the container:"
splunk_sh "ls -1 '${DEPLOY_APPS_PATH}'"

info "Host-side forwarder client template (for reference):"
info "  ${APPS_DIR}/forwarder-client-template/local/deploymentclient.conf"
info "  Copy to \$SPLUNK_HOME/etc/system/local/deploymentclient.conf on each forwarder."
