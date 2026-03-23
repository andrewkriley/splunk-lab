#!/bin/bash
# lib.sh - Shared helpers: Proxmox API and LXC SSH access.
# Source this file; do not execute directly.

: "${PROXMOX_HOST:?}" "${PROXMOX_NODE:?}" "${PROXMOX_API_TOKEN_ID:?}" "${PROXMOX_API_TOKEN_SECRET:?}"

PROXMOX_API_PORT="${PROXMOX_API_PORT:-8006}"
_PVE_BASE="https://${PROXMOX_HOST}:${PROXMOX_API_PORT}/api2/json"
_TLS_FLAG=$([ "${PROXMOX_TLS_VERIFY:-false}" = "true" ] && echo "" || echo "--insecure")

# Derive LXC IP address (strip CIDR prefix) if LXC_IP is set
LXC_IP_ADDR="$(echo "${LXC_IP:-}" | cut -d'/' -f1)"

# Build SSH options; honour LXC_SSH_KEY if set
_SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
[[ -n "${LXC_SSH_KEY:-}" ]] && _SSH_OPTS="${_SSH_OPTS} -i ${LXC_SSH_KEY}"

# ---------------------------------------------------------------------------
# Proxmox API helpers
# ---------------------------------------------------------------------------

# pve_api METHOD /path [--data-raw '{...}']
# Makes an authenticated request to the Proxmox API and prints the response body.
pve_api() {
    local method="$1" path="$2"
    shift 2
    # shellcheck disable=SC2086
    curl -sf $( echo $_TLS_FLAG) -X "$method" \
        -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}" \
        -H "Content-Type: application/json" \
        "${_PVE_BASE}${path}" "$@"
}

# wait_for_task UPID
# Polls a Proxmox task until it stops. Exits non-zero on task failure.
wait_for_task() {
    local upid="$1"
    local upid_enc
    upid_enc=$(printf '%s' "$upid" | jq -Rr @uri)

    echo -n "    Waiting"
    while true; do
        local result status
        result=$(pve_api GET "/nodes/${PROXMOX_NODE}/tasks/${upid_enc}/status")
        status=$(echo "$result" | jq -r '.data.status')
        if [[ "$status" == "stopped" ]]; then
            local exitstatus
            exitstatus=$(echo "$result" | jq -r '.data.exitstatus')
            echo " done."
            if [[ "$exitstatus" != "OK" ]]; then
                echo "ERROR: Task failed (${exitstatus}). Output:"
                pve_api GET "/nodes/${PROXMOX_NODE}/tasks/${upid_enc}/log" \
                    | jq -r '.data[].t' 2>/dev/null || true
                return 1
            fi
            return 0
        fi
        echo -n "."
        sleep 3
    done
}

# pve_exec VMID CMD [ARGS...]
# Runs a command inside a running LXC container via the Proxmox API.
# Used only during container bootstrap (e.g. writing the initial SSH key).
pve_exec() {
    local vmid="$1"
    shift
    local cmd_json
    cmd_json=$(jq -n '$ARGS.positional' --args -- "$@")

    local upid
    upid=$(pve_api POST "/nodes/${PROXMOX_NODE}/lxc/${vmid}/exec" \
        --data-raw "{\"command\": ${cmd_json}}" | jq -r '.data')

    wait_for_task "$upid"

    local upid_enc
    upid_enc=$(printf '%s' "$upid" | jq -Rr @uri)
    pve_api GET "/nodes/${PROXMOX_NODE}/tasks/${upid_enc}/log" \
        | jq -r '.data[].t' 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# LXC SSH helpers (used by install-splunk.sh and configure-splunk.sh)
# ---------------------------------------------------------------------------

# lxc_ssh CMD [ARGS...]
# Runs a command on the LXC as root via SSH.
lxc_ssh() {
    # shellcheck disable=SC2086
    ssh ${_SSH_OPTS} root@"${LXC_IP_ADDR}" "$@"
}

# lxc_scp SRC DST
# Copies a file to/from the LXC via SCP.
lxc_scp() {
    # shellcheck disable=SC2086
    scp ${_SSH_OPTS} "$@"
}
