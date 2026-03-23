#!/bin/bash
# configure-splunk.sh - Wait for Splunk to be ready, then configure HEC and (optionally) apply a license

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"
source "${SCRIPT_DIR}/lib.sh"

HTTP_PORT="${SPLUNK_HTTP_PORT:-8000}"
MGMT_PORT="${SPLUNK_MGMT_PORT:-8089}"
HEC_PORT="${SPLUNK_HEC_PORT:-8088}"
INDEX_PORT="${SPLUNK_INDEX_PORT:-9997}"
AUTH="${SPLUNK_ADMIN_USER:-admin}:${SPLUNK_ADMIN_PASSWORD}"

# ---------------------------------------------------------------------------
# 1. Wait for Splunk Web to be reachable
# ---------------------------------------------------------------------------
echo "==> Waiting for Splunk to be ready at http://${LXC_IP_ADDR}:${HTTP_PORT}..."
max_wait=300
elapsed=0
while ! lxc_ssh "curl -sf http://localhost:${HTTP_PORT}" &>/dev/null; do
    if [[ $elapsed -ge $max_wait ]]; then
        echo "ERROR: Splunk did not become ready within ${max_wait}s."
        echo "       Check container status: ssh root@${LXC_IP_ADDR} docker compose -f /opt/splunk-docker/docker-compose.yml ps"
        exit 1
    fi
    echo -n "."
    sleep 10
    elapsed=$((elapsed + 10))
done
echo " ready."

# ---------------------------------------------------------------------------
# 2. Enable HEC and create a token
# ---------------------------------------------------------------------------
echo "==> Enabling HTTP Event Collector..."
lxc_ssh "docker exec splunk /opt/splunk/bin/splunk http-event-collector enable -auth '${AUTH}'" || true

if [[ -z "${SPLUNK_HEC_TOKEN:-}" ]]; then
    echo "==> Creating HEC token (default-hec)..."
    hec_token=$(lxc_ssh "docker exec splunk /opt/splunk/bin/splunk http-event-collector create default-hec \
        -auth '${AUTH}' --index main --sourcetype _json -output_mode json" \
        | jq -r '.entry[0].content.token // empty' 2>/dev/null || true)

    if [[ -n "$hec_token" ]]; then
        echo "    HEC token: ${hec_token}"
        echo "    Add SPLUNK_HEC_TOKEN=${hec_token} to your .env to retain it."
    else
        echo "    Warning: could not retrieve HEC token — configure manually in Splunk Web."
    fi
else
    echo "==> HEC token already set in .env (${SPLUNK_HEC_TOKEN:0:8}...)."
    hec_token="${SPLUNK_HEC_TOKEN}"
fi

# ---------------------------------------------------------------------------
# 3. Enable forwarder receiving
# ---------------------------------------------------------------------------
echo "==> Enabling forwarder receiving on port ${INDEX_PORT}..."
lxc_ssh "docker exec splunk /opt/splunk/bin/splunk enable listen ${INDEX_PORT} -auth '${AUTH}'" || true

# ---------------------------------------------------------------------------
# 4. Apply license file (optional)
# ---------------------------------------------------------------------------
if [[ -n "${SPLUNK_LICENSE_FILE:-}" && -f "${SPLUNK_LICENSE_FILE}" ]]; then
    echo "==> Applying license file (${SPLUNK_LICENSE_FILE})..."
    lxc_scp "${SPLUNK_LICENSE_FILE}" "root@${LXC_IP_ADDR}:/tmp/splunk.license"
    lxc_ssh "docker exec splunk /opt/splunk/bin/splunk add licenses /tmp/splunk.license -auth '${AUTH}'"
    lxc_ssh "rm /tmp/splunk.license"
    lxc_ssh "docker exec splunk /opt/splunk/bin/splunk restart"
    echo "    License applied."
fi

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Splunk is ready."
echo "    Web UI:  http://${LXC_IP_ADDR}:${HTTP_PORT}"
echo "    HEC:     http://${LXC_IP_ADDR}:${HEC_PORT}/services/collector"
echo "    Indexer: ${LXC_IP_ADDR}:${INDEX_PORT}"
echo "    API:     https://${LXC_IP_ADDR}:${MGMT_PORT}"
if [[ -n "${hec_token:-}" ]]; then
    echo "    HEC token: ${hec_token}"
fi
