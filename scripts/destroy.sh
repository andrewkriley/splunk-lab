#!/bin/bash
# destroy.sh - Stop and destroy the Splunk LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

echo "WARNING: This will permanently destroy container ${LXC_ID} (${LXC_HOSTNAME})."
read -rp "Type 'yes' to confirm: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 1; }

ssh "${PROXMOX_USER}@${PROXMOX_HOST}" -p "${PROXMOX_PORT}" bash <<EOF
set -euo pipefail
echo "==> Stopping container ${LXC_ID}..."
pct stop ${LXC_ID} || true
sleep 3
echo "==> Destroying container ${LXC_ID}..."
pct destroy ${LXC_ID}
echo "==> Done."
EOF
