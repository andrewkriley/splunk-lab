#!/usr/bin/env bash
# Shared helpers for the deployment-server configuration scripts.
# Source this file from each numbered step script.

set -euo pipefail

# Resolve the repo root regardless of where the script was invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_ROOT="${REPO_ROOT}/scripts/deployment-server"
APPS_DIR="${SCRIPT_ROOT}/apps"

# Container + Splunk paths.
SPLUNK_SERVICE="${SPLUNK_SERVICE:-splunk}"
SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"
SPLUNK_RECEIVING_PORT="${SPLUNK_RECEIVING_PORT:-9997}"
DEPLOY_APPS_PATH="${SPLUNK_HOME}/etc/deployment-apps"
SYSTEM_LOCAL_PATH="${SPLUNK_HOME}/etc/system/local"

# ── Colours ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
  CYAN=''; GREEN=''; YELLOW=''; RED=''; BOLD=''; NC=''
fi

info()    { echo -e "  ${CYAN}$*${NC}"; }
success() { echo -e "  ${GREEN}✓ $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠  $*${NC}"; }
err()     { echo -e "  ${RED}✗ $*${NC}" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}── $* ──${NC}\n"; }

# ── Preconditions ────────────────────────────────────────────────────────────
require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    err "docker CLI not found — install Docker Desktop first"
    return 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    err "docker compose v2 plugin missing"
    return 1
  fi
}

require_splunk_running() {
  cd "$REPO_ROOT"
  local state
  state=$(docker compose ps --status running --services 2>/dev/null || true)
  if ! echo "$state" | grep -qx "$SPLUNK_SERVICE"; then
    err "Splunk container '${SPLUNK_SERVICE}' is not running — start the stack with 'docker compose up -d'"
    return 1
  fi
}

load_splunk_password() {
  local env_file="${REPO_ROOT}/.env"
  if [[ ! -f "$env_file" ]]; then
    err ".env not found at ${env_file} — run ./install.sh first"
    return 1
  fi
  # Split on the first '=' so passwords with '=' survive.
  SPLUNK_PASSWORD=$(awk -F= '/^SPLUNK_PASSWORD=/ { sub(/^SPLUNK_PASSWORD=/, ""); print; exit }' "$env_file")
  if [[ -z "${SPLUNK_PASSWORD:-}" ]]; then
    err "SPLUNK_PASSWORD is empty in ${env_file}"
    return 1
  fi
  export SPLUNK_PASSWORD
}

# ── Splunk CLI / container helpers ───────────────────────────────────────────
# Run arbitrary shell inside the Splunk container as the splunk user.
splunk_sh() {
  cd "$REPO_ROOT"
  docker compose exec -T -u splunk "$SPLUNK_SERVICE" bash -c "$*"
}

# Run a splunk CLI subcommand authenticated as admin. Appends -auth.
splunk_cli() {
  cd "$REPO_ROOT"
  docker compose exec -T -u splunk "$SPLUNK_SERVICE" \
    "${SPLUNK_HOME}/bin/splunk" "$@" -auth "admin:${SPLUNK_PASSWORD}"
}

# Copy a host directory into the Splunk container at the given container path.
# Uses docker cp so it works regardless of whether the directory is bind-mounted.
copy_into_container() {
  local src="$1" dest="$2"
  cd "$REPO_ROOT"
  local cid
  cid=$(docker compose ps -q "$SPLUNK_SERVICE")
  if [[ -z "$cid" ]]; then
    err "Could not resolve container id for service ${SPLUNK_SERVICE}"
    return 1
  fi
  # Ensure destination parent exists and is owned by splunk.
  docker exec -u root "$cid" bash -c "mkdir -p '$(dirname "$dest")' && chown -R splunk:splunk '$(dirname "$dest")'"
  docker cp "$src" "${cid}:${dest}"
  docker exec -u root "$cid" chown -R splunk:splunk "$dest"
}

bootstrap() {
  require_docker
  require_splunk_running
  load_splunk_password
}
