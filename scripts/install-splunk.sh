#!/bin/bash
# install-splunk.sh - Install Splunk Enterprise inside the LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

LXC_IP_ADDR="$(echo ${LXC_IP} | cut -d'/' -f1)"
SPLUNK_DEB="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-amd64.deb"
SPLUNK_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_DEB}"

echo "==> Installing Splunk Enterprise ${SPLUNK_VERSION} on ${LXC_IP_ADDR}"

# Run installation inside the container via Proxmox exec
ssh "${PROXMOX_USER}@${PROXMOX_HOST}" -p "${PROXMOX_PORT}" bash <<EOF
set -euo pipefail

echo "==> Updating container packages..."
pct exec ${LXC_ID} -- bash -c "apt-get update && apt-get upgrade -y"

echo "==> Installing dependencies..."
pct exec ${LXC_ID} -- bash -c "apt-get install -y wget curl net-tools"

echo "==> Downloading Splunk Enterprise ${SPLUNK_VERSION}..."
pct exec ${LXC_ID} -- bash -c "wget -q '${SPLUNK_URL}' -O /tmp/${SPLUNK_DEB}"

echo "==> Installing Splunk..."
pct exec ${LXC_ID} -- bash -c "dpkg -i /tmp/${SPLUNK_DEB} && rm /tmp/${SPLUNK_DEB}"

echo "==> Accepting license and setting admin credentials..."
pct exec ${LXC_ID} -- bash -c "
    /opt/splunk/bin/splunk start --accept-license --no-prompt \
        --answer-yes \
        --seed-passwd '${SPLUNK_ADMIN_PASSWORD}'
"

echo "==> Enabling Splunk to start at boot..."
pct exec ${LXC_ID} -- bash -c "/opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --no-prompt --answer-yes"

echo "==> Splunk installation complete."
pct exec ${LXC_ID} -- bash -c "/opt/splunk/bin/splunk status"
EOF

echo ""
echo "==> Splunk Enterprise is running."
echo "    Web UI:  http://${LXC_IP_ADDR}:${SPLUNK_HTTP_PORT}"
echo "    User:    ${SPLUNK_ADMIN_USER}"
