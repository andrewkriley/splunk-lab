#!/bin/bash
# destroy.sh - Stop and destroy the Splunk LXC container via Proxmox API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"
source "${SCRIPT_DIR}/lib.sh"

echo "WARNING: This will permanently destroy container ${LXC_ID} (${LXC_HOSTNAME})."
read -rp "Type 'yes' to confirm: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 1; }

echo "==> Stopping container ${LXC_ID}..."
upid=$(pve_api POST "/nodes/${PROXMOX_NODE}/lxc/${LXC_ID}/status/stop" | jq -r '.data')
wait_for_task "$upid" || true  # container may already be stopped

echo "==> Destroying container ${LXC_ID}..."
upid=$(pve_api DELETE "/nodes/${PROXMOX_NODE}/lxc/${LXC_ID}?purge=1" | jq -r '.data')
wait_for_task "$upid"

echo "==> Done. Container ${LXC_ID} has been destroyed."
