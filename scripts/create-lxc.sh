#!/bin/bash
# create-lxc.sh - Create Ubuntu 24.04.4 LXC container on Proxmox via API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Copy .env.example to .env and configure your values."
    exit 1
fi

source "$ENV_FILE"
source "${SCRIPT_DIR}/lib.sh"

echo "==> Creating LXC container ${LXC_ID} (${LXC_HOSTNAME}) on ${PROXMOX_HOST} (node: ${PROXMOX_NODE})"

# Check container ID is not already in use
if pve_api GET "/nodes/${PROXMOX_NODE}/lxc/${LXC_ID}/status/current" &>/dev/null; then
    echo "Error: Container ID ${LXC_ID} already exists."
    exit 1
fi

# Check if the template is already downloaded
TEMPLATE_NAME="ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
echo "==> Checking for template ${TEMPLATE_NAME}..."
template_exists=$(pve_api GET "/nodes/${PROXMOX_NODE}/storage/local/content?content=vztmpl" \
    | jq -r --arg t "$TEMPLATE_NAME" '.data[] | select(.volid | endswith($t)) | .volid' 2>/dev/null || true)

if [[ -z "$template_exists" ]]; then
    echo "==> Template not found — downloading..."
    upid=$(pve_api POST "/nodes/${PROXMOX_NODE}/aplinfo" \
        --data-raw "{\"storage\": \"local\", \"template\": \"${TEMPLATE_NAME}\"}" \
        | jq -r '.data')
    wait_for_task "$upid"
    echo "==> Template downloaded."
else
    echo "==> Template already present: ${template_exists}"
fi

# Create the container
echo "==> Creating container..."
upid=$(pve_api POST "/nodes/${PROXMOX_NODE}/lxc" --data-raw "$(jq -n \
    --argjson vmid   "$LXC_ID" \
    --arg     ostemplate "$LXC_TEMPLATE" \
    --arg     hostname   "$LXC_HOSTNAME" \
    --arg     password   "$LXC_PASSWORD" \
    --argjson cores      "$LXC_CORES" \
    --argjson memory     "$LXC_MEMORY" \
    --argjson swap       "$LXC_SWAP" \
    --arg     rootfs     "${LXC_STORAGE}:${LXC_DISK}" \
    --arg     net0       "name=eth0,bridge=${LXC_BRIDGE},ip=${LXC_IP},gw=${LXC_GATEWAY}" \
    --arg     nameserver "$LXC_DNS" \
    '{
        vmid: $vmid,
        ostemplate: $ostemplate,
        hostname: $hostname,
        password: $password,
        cores: $cores,
        memory: $memory,
        swap: $swap,
        rootfs: $rootfs,
        net0: $net0,
        nameserver: $nameserver,
        unprivileged: 1,
        features: "nesting=1",
        onboot: 1
    }')" | jq -r '.data')
wait_for_task "$upid"

# Start the container
echo "==> Starting container ${LXC_ID}..."
upid=$(pve_api POST "/nodes/${PROXMOX_NODE}/lxc/${LXC_ID}/status/start" | jq -r '.data')
wait_for_task "$upid"

echo "==> Waiting for container to be ready..."
sleep 5

# Bootstrap SSH access: write the user's public key into /root/.ssh/authorized_keys
# using pve_exec (the only time the Proxmox exec API is needed).
LXC_SSH_PUBKEY="${LXC_SSH_PUBKEY:-${HOME}/.ssh/id_rsa.pub}"
if [[ ! -f "${LXC_SSH_PUBKEY}" ]]; then
    echo "ERROR: SSH public key not found at ${LXC_SSH_PUBKEY}"
    echo "       Set LXC_SSH_PUBKEY in .env or generate a key with: ssh-keygen -t rsa"
    exit 1
fi

echo "==> Bootstrapping SSH access (${LXC_SSH_PUBKEY})..."
pubkey_content=$(cat "${LXC_SSH_PUBKEY}")
pve_exec "$LXC_ID" bash -c \
    "mkdir -p /root/.ssh && chmod 700 /root/.ssh && echo '${pubkey_content}' > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
echo "==> SSH access configured."

echo "==> LXC container created and started."
echo "    Access: ssh root@$(echo "${LXC_IP}" | cut -d'/' -f1)"
