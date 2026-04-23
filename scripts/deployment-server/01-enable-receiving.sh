#!/usr/bin/env bash
# Step 1 — turn this Splunk Enterprise instance into a receiver for forwarder
# traffic by opening the splunktcp listener on ${SPLUNK_RECEIVING_PORT} (9997
# by default). Both universal forwarders and heavy forwarders send to the same
# port — the HF just happens to parse events before transmitting.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

header "Step 1 — enable receiving on :${SPLUNK_RECEIVING_PORT}"

bootstrap

if splunk_cli display listen-ports 2>/dev/null | grep -q "^${SPLUNK_RECEIVING_PORT}$"; then
  success "Receiver already listening on :${SPLUNK_RECEIVING_PORT} — skipping enable"
else
  info "Running 'splunk enable listen ${SPLUNK_RECEIVING_PORT}'…"
  splunk_cli enable listen "${SPLUNK_RECEIVING_PORT}"
  success "Receiver enabled on :${SPLUNK_RECEIVING_PORT}"
fi

info "Current splunktcp listeners:"
splunk_cli display listen-ports 2>/dev/null || warn "display listen-ports not supported on this build"

warn "Forwarders now need line-of-sight to ${SPLUNK_SERVICE}:${SPLUNK_RECEIVING_PORT}"
warn "In this lab the port is NOT published on the host — add a '- \"127.0.0.1:${SPLUNK_RECEIVING_PORT}:${SPLUNK_RECEIVING_PORT}\"' entry to docker-compose.yml if you want to forward from outside the Docker network."
