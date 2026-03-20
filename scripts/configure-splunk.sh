#!/bin/bash
# configure-splunk.sh - Post-install configuration for Splunk Enterprise

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

echo "==> Configuring Splunk Enterprise on container ${LXC_ID}"

ssh "${PROXMOX_USER}@${PROXMOX_HOST}" -p "${PROXMOX_PORT}" bash <<EOF
set -euo pipefail

SPLUNK="/opt/splunk/bin/splunk"
AUTH="-auth ${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASSWORD}"

# Enable HTTP Event Collector
echo "==> Enabling HTTP Event Collector (HEC) on port ${SPLUNK_HEC_PORT}..."
pct exec ${LXC_ID} -- bash -c "
    \$SPLUNK http-event-collector enable \$AUTH
    \$SPLUNK http-event-collector create default-hec \$AUTH \
        --index main \
        --sourcetype _json
"

# Enable receiving (indexer port for forwarders)
echo "==> Enabling receiving on port ${SPLUNK_INDEX_PORT}..."
pct exec ${LXC_ID} -- bash -c "
    \$SPLUNK enable listen ${SPLUNK_INDEX_PORT} \$AUTH
"

# Apply license if provided
if [[ -n "${SPLUNK_LICENSE_FILE:-}" && -f "${SPLUNK_LICENSE_FILE}" ]]; then
    echo "==> Applying Splunk license..."
    # Copy license into container and apply
    pct push ${LXC_ID} "${SPLUNK_LICENSE_FILE}" /tmp/splunk.license
    pct exec ${LXC_ID} -- bash -c "\$SPLUNK add licenses /tmp/splunk.license \$AUTH && rm /tmp/splunk.license"
else
    echo "==> No license file set — running as Splunk Free Trial."
fi

# Restart Splunk to apply changes
echo "==> Restarting Splunk..."
pct exec ${LXC_ID} -- bash -c "\$SPLUNK restart"

echo "==> Configuration complete."
EOF

LXC_IP_ADDR="$(echo ${LXC_IP} | cut -d'/' -f1)"
echo ""
echo "==> Splunk is ready."
echo "    Web UI:  http://${LXC_IP_ADDR}:${SPLUNK_HTTP_PORT}"
echo "    HEC:     http://${LXC_IP_ADDR}:${SPLUNK_HEC_PORT}/services/collector"
echo "    Indexer: ${LXC_IP_ADDR}:${SPLUNK_INDEX_PORT}"
