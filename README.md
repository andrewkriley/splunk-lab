# partner-mcp-splunk-lab

Deploy Splunk Enterprise as a Docker container inside an Ubuntu 24.04.4 LXC on Proxmox.

## Architecture

```
Your machine  →  Proxmox API  →  LXC (Ubuntu 24.04)  →  Docker  →  splunk/splunk
```

- **LXC lifecycle** (create/destroy) is managed via the Proxmox REST API.
- **Everything inside the LXC** (Docker install, Splunk config) is done over SSH.

## Prerequisites

- Proxmox VE host with API token access
- Ubuntu 24.04 LXC template available (or downloadable via `pveam`)
- An SSH key pair on your local machine — the public key is written to the LXC's `root` account at creation time
- `curl`, `jq`, `ssh`, `scp` available on your local machine

## Setup

1. Copy the example environment file and configure your values:

```bash
cp .env.example .env
```

2. Edit `.env` with your Proxmox host, LXC specs, and Splunk credentials.

## Usage

### Full deployment (create LXC + install Docker + configure Splunk)

```bash
bash scripts/deploy.sh
```

### Step-by-step

```bash
# 1. Create the LXC container and bootstrap SSH access
bash scripts/create-lxc.sh

# 2. Install Docker Engine and start the Splunk container
bash scripts/install-splunk.sh

# 3. Wait for readiness, configure HEC and receiving
bash scripts/configure-splunk.sh
```

### Destroy the lab

```bash
bash scripts/destroy.sh
```

## Configuration

All variables are set in `.env`. See `.env.example` for the full reference.

| Variable | Description |
|---|---|
| `PROXMOX_HOST` | Proxmox host IP or hostname |
| `PROXMOX_NODE` | Proxmox node name (e.g. `pve`) |
| `PROXMOX_API_TOKEN_ID` | API token ID (`user@realm!tokenname`) |
| `PROXMOX_API_TOKEN_SECRET` | API token secret |
| `LXC_ID` | Proxmox container ID |
| `LXC_IP` | Container static IP in CIDR notation (e.g. `192.168.1.200/24`) |
| `LXC_SSH_PUBKEY` | Path to your SSH public key (default: `~/.ssh/id_rsa.pub`) |
| `SPLUNK_IMAGE` | Docker image to use (default: `splunk/splunk:latest`) |
| `SPLUNK_ADMIN_PASSWORD` | Splunk admin password |
| `SPLUNK_ROLE` | Splunk role (default: `splunk_standalone`) |
| `SPLUNK_MEMORY_LIMIT` | Container memory limit (default: `8G`) |
| `SPLUNK_MEMORY_RESERVATION` | Container memory reservation (default: `4G`) |
| `SPLUNK_LICENSE_URI` | `Free` for trial, or a URI/path for Enterprise |
| `SPLUNK_LICENSE_FILE` | Local path to a `.lic` file (pushed at configure time) |
| `SPLUNK_HEC_TOKEN` | Pre-set HEC token; leave blank to auto-generate |

## Ports

| Port | Service |
|---|---|
| `8000` | Splunk Web UI |
| `8089` | Splunk management API |
| `8088` | HTTP Event Collector (HEC) |
| `9997` | Splunk forwarder receiving |
| `514/udp` | Syslog |

## SSH key setup

`create-lxc.sh` reads `LXC_SSH_PUBKEY` (default `~/.ssh/id_rsa.pub`) and writes it to `/root/.ssh/authorized_keys` inside the LXC immediately after container creation. All subsequent scripts connect directly via SSH — no Proxmox API proxy for in-container operations.

If you do not have an SSH key pair yet:

```bash
ssh-keygen -t rsa -b 4096
```
