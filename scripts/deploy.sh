#!/bin/bash
# deploy.sh - Full deployment: create LXC, install and configure Splunk

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo " Splunk Enterprise Lab Deployment"
echo "========================================"
echo ""

echo "[1/3] Creating LXC container..."
bash "${SCRIPT_DIR}/create-lxc.sh"

echo ""
echo "[2/3] Installing Splunk Enterprise..."
bash "${SCRIPT_DIR}/install-splunk.sh"

echo ""
echo "[3/3] Configuring Splunk..."
bash "${SCRIPT_DIR}/configure-splunk.sh"

echo ""
echo "========================================"
echo " Deployment complete!"
echo "========================================"
