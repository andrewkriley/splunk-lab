#!/bin/bash
# create-lxc.sh - Create Ubuntu 24.04.4 LXC container on Proxmox for Splunk Enterprise

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Copy .env.example to .env and configure your values."
    exit 1
fi

source "$ENV_FILE"

echo "==> Creating LXC container ${LXC_ID} (${LXC_HOSTNAME}) on Proxmox ${PROXMOX_HOST}"

ssh "${PROXMOX_USER}@${PROXMOX_HOST}" -p "${PROXMOX_PORT}" bash <<EOF
set -euo pipefail

# Check container ID is not already in use
if pct status ${LXC_ID} &>/dev/null; then
    echo "Error: Container ID ${LXC_ID} already exists."
    exit 1
fi

# Check template exists
if ! pveam list local | grep -q "ubuntu-24.04"; then
    echo "==> Downloading Ubuntu 24.04 template..."
    pveam update
    pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
fi

echo "==> Creating container..."
pct create ${LXC_ID} ${LXC_TEMPLATE} \
    --hostname ${LXC_HOSTNAME} \
    --password ${LXC_PASSWORD} \
    --cores ${LXC_CORES} \
    --memory ${LXC_MEMORY} \
    --swap ${LXC_SWAP} \
    --rootfs ${LXC_STORAGE}:${LXC_DISK} \
    --net0 name=eth0,bridge=${LXC_BRIDGE},ip=${LXC_IP},gw=${LXC_GATEWAY} \
    --nameserver ${LXC_DNS} \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1 \
    --start 1

echo "==> Waiting for container to start..."
sleep 5

echo "==> Container ${LXC_ID} created and started."
pct status ${LXC_ID}
EOF

echo "==> LXC container created successfully."
echo "    Access: ssh root@$(echo ${LXC_IP} | cut -d'/' -f1)"
